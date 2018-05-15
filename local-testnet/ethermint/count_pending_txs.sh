#!/bin/bash

# Reports the number of pending transactions per node of a given testnet

# usage: $0 <testnet name>

set -e
set -u

name=$1

pushd $name
nr_nodes=`cat nr_nodes`

for i in $(seq 1 $nr_nodes); do
	ipcfile=node$i/geth.ipc

	if [[ ! -S $ipcfile ]]; then
		echo "node $i: ipc file $ipcfile doesn't exist or isn't a socket"
		continue
	fi

	ret=`echo '{"jsonrpc":"2.0","method":"eth_pendingTransactions","params":[],"id":1}' | nc -U $ipcfile`
	if echo $ret | jq -r -e ".error" > /dev/null ; then
		echo "node $i: error $ret"
	else
		echo "node $i: `echo $ret | jq -r '.result[].hash' | wc -l`"
	fi
done
