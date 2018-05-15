#!/bin/bash

# usage $? <testnet name> <batch size> <pause (seconds) between batches> 

set -e
set -u

name=$1
batch_size=$2
pause=$3

# This script uses unix sockets IPC which is faster than TCP sockets.
# In case unix sockets were not available (e.g. for remote invocation), the command could be like this:
# curl --data '{"jsonrpc":"2.0","method":"personal_unlockAccount","params":["0x7eff122b94897ea5b0e2a9abf47b86337fafebdc","1234"],"id":1}' -X POST -H "Content-Type: application/json"

pushd $name
nr_nodes=`cat nr_nodes`

for i in $(seq 1 $nr_nodes); do
	# the actual work is done in a subshell per node, running in background in order to achieve parallelization.
	# subshells here also provide separation of environments, something mere command grouping with { } doesn't provide
	(
		# It's important for each node to have a distinct sender account, otherwise conflicting txs (same nonce) would be created
		myaddr="0x`cat node$i/keystore/primary.json | jq -r '.address'`"
		ipcfile="node$i/geth.ipc"

		# first, unlock the account. Doc: https://github.com/ethereum/go-ethereum/wiki/Management-APIs#personal_unlockaccount
		# CAUTION: account address and password are hardcoded here to the Ethermint default. Should be read from somewhere instead.
		ret=`echo '{"jsonrpc":"2.0","method":"personal_unlockAccount","params":["'$myaddr'", "", 0],"id":1}' | nc -U $ipcfile`
		echo "unlock $i (pid $$) returned $ret"


		# here we do the batching: one write to the socket file contains multiple calls of send_transaction. 
		# Not sure how much of a difference it makes with unix sockets where the overhead of opening a connection is minimal compared to TCP.
		# It probably depends on the client implementation, how it dispatches requests, to how many threads etc.
		# Varying the batch size can give us an idea...
		loop_cnt=0
		# just keep looping until the parent process exits
		while true; do
			# build a list of commands through string concatenation...
			cmds=""
			for j in $(seq 1 $batch_size); do
				cmd='{"jsonrpc":"2.0","method":"eth_sendTransaction","params":[{"from":"'$myaddr'","to":'`cat ../1000_addrs.txt | shuf -n 1`', "value":"'`printf "0x%x" $((RANDOM*10000000000))`'"}],"id":'$j'}'
				cmds="$cmds $cmd"
			done

			# now execute it (writing it to the socket) and print the returned value
			ret=`echo $cmds | nc -U $ipcfile`
			loop_cnt=$(($loop_cnt+1))
			echo "txs $i (round $loop_cnt) returned $ret"	

			# throttling according to the user delivered pause parameter.
			sleep $pause
		done
	) &
done

echo "waiting for everything to finish..."
wait
