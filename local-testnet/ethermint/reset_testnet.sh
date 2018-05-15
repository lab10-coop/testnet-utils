#!/bin/bash

# usage: $0 <testnet name>
# resets the given testnet to the state to which it was initialized

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

for i in $(seq 1 $nr_nodes); do
	nodedir="node$i"
	echo "resetting $nodedir"

	tendermint --home $nodedir unsafe_reset_all

	ethermint --datadir $nodedir unsafe_reset_all
	# after ethermint reset, we need to re-init it, otherwise it will pretend to work, but then fail.
	# More precisely, if started without prior init, it will create a genesis block with nonsense values (e.g. gaslimit of ~5000)
	ethermint --datadir $nodedir init eth_genesis.json
done

echo "all done"
