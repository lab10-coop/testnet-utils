#!/bin/bash

# usage: $0 <testnet name>
# runs all tendermint and ethermint nodes for the specified testnet (needs to already be initialized)

set -e
set -u

name=$1

die() {
	echo "$*" 1>&2
	exit 1
}

# some sanity checks

if [[ ! -d $name ]]; then
	die "$name does not exist"
fi

pushd $name

nr_nodes=`cat nr_nodes`
if [ ! "$nr_nodes" -eq "$nr_nodes" ]; then
	die "no valid number found in file nr_nodes"
fi

check_jobs() {
	# display jobs stopped since last check
	jobs -lns
}

pids=()
mkdir -p logs
#set -o monitor
#trap check_jobs CHLD
for i in $(seq 1 $nr_nodes); do
	nodedir="node$i"

	tm_extra_args="--log_level p2p:info,state:info,consensus:info,*:error" # "--log_level info"
	tendermint --home $nodedir $tm_extra_args node &> logs/tm$i.log &
	# push pid of spawned process to pids array
	pids+=($!)
	echo "$nodedir: tendermint pid ${pids[-1]}"

	tm_port=$((20007+(10*$i)))
	abci_port=$((20008+(10*$i)))
	rpc_port=$((20001+(10*$i)))
	ws_port=$((20002+(10*$i)))
	p2p_port=$((20003+(10*$i)))
	em_extra_args="--rpc --rpcport $rpc_port --rpccorsdomain '*' --rpcapi eth,net,web3,personal,admin --ws --wsport $ws_port --wsorigins '*'"
	if [[ $i == 1 ]]; then
		em_extra_args="$em_extra_args --rpcaddr=0.0.0.0"
	fi
	ethermint --datadir $nodedir --tendermint_addr tcp://localhost:$tm_port --abci_laddr tcp://localhost:$abci_port $em_extra_args &> logs/em$i.logs &
	pids+=($!)
	echo "$nodedir: ethermint pid ${pids[-1]}"

	# a wait here seems to avoid failure to start ethermint due to port 30303 being occupied.
	# looks like it briefly binds that port and than immediately frees it. Since there's no cmdline param to change the port, that's probably the best workaround
	sleep 0.2
done

echo "started jobs: ${pids[*]}"

echo
echo "waiting for termination..."
echo

kill_all() {
	if kill ${pids[*]}; then
		echo "kill_all succeeded"
	else
		echo "### kill_all didn't succeed. Check manually!"
		# kill -9 would probably do the job reliably. But I don't want to be brutal by default
	fi
}

#trap "kill ${pids[*]}" SIGINT SIGTERM
trap kill_all SIGINT SIGTERM

# now block (waits for all children to exit)
#wait ${pids[*]}
#wait

prev_state=""
while true; do
	dead_procs=("")
	for pid in ${pids[*]}; do
		if ! ps $pid > /dev/null; then
			dead_procs+=($pid)
		fi
	done
	
	if [[ "${dead_procs[*]}" != $prev_state ]]; then
		echo "### dead processes: ${dead_procs[*]}"
		prev_state="${dead_procs[*]}"
	fi
	
	if [[ `jobs | wc -l` == 0 ]]; then
		echo "no jobs remaining. Exiting"
		exit
	fi
	sleep 5
done

# Unfortunately, bash seems to not offer a more elegant way to monitor background jobs.
# While one can just use "wait" to have the script wait for child processes, this won't notify about dying children.
# trapping SIGCHLD shouldn't in theory achieve just that, but it doesn't work in scripts, because "job control" is off in non-interactive mode (script).
# While job control can be manually turned on, it just leads to another set of issues. See https://stackoverflow.com/questions/6769414/bash-restart-sub-process-using-trap-sigchld
