#!/bin/bash

# usage: $0 <testnet name> <nr nodes>
# requires jq to be installed: apt install jq

set -e
set -u

name=$1
nr_nodes=$2

if [[ ! -d $name ]]; then
	echo "creating $name..."
	mkdir -p $name
fi

pushd $name

# we won't silently overwrite an existing genesis file
if [[ -f tm_genesis.json ]]; then
	echo "file tm_genesis.json already exists. Delete if you really want to create a new one! Aborting."
	exit 1
fi

echo $nr_nodes > nr_nodes

# first, create the validator accounts
rm -f validators.tmp
rm -f seeds.tmp
for i in $(seq 1 $nr_nodes); do
	file=validator_$i.json
	tendermint gen_validator > $file
	addr=$(cat $file | jq -r ".pub_key.data")
	
	cat <<EOF >> validators.tmp
{"pub_key": {"type":"ed25519","data":"$addr"},"power":10,"name":"validator$i"}
EOF

	p2p_addr="127.0.0.1:$((20006+(10*$i)))"
	echo $p2p_addr >> seeds.tmp
done

# assemble the list of the node's primary ETH accounts in order to pre-fund them via genesis
rm -f allocs.tmp
for i in $(seq 1 $nr_nodes); do
	file=../eth_accounts/$i.json
	addr=$(cat $file | jq -r ".address")
    cat <<EOF >> allocs.tmp
"$addr": { "balance": "10000000000000000000000000" }
EOF
done


# now assemble the genesis file
# this doesn't produce the prettiest output (validators in one line), but valid one. Pipe to jq in order to prettify!
cat <<EOF >> tm_genesis.json
{
	"genesis_time": "`date --iso-8601=seconds -u`",
	"chain_id": "$name",
	"validators": [
		`cat validators.tmp | paste -sd ","`
	],
	"app_hash":""
}
EOF

# now initialize a directory per node (tendermint and ethermint)
for i in $(seq 1 $nr_nodes); do
	nodedir="node$i"
	echo "initializing $nodedir"
	mkdir $nodedir

    # priv_validator.json is the default name
	cp validator_$i.json $nodedir/priv_validator.json
	cd $nodedir
	ln -s ../tm_genesis.json genesis.json
	mkdir data

# config doc: http://tendermint.readthedocs.io/projects/tools/en/v0.14.0/specification/configuration.html
# every node shifts the ports by 10. E.g. for node1, proxy_app port will be 20018, for node2 20028, for node399 23998 etc.
cat <<EOF >> config.toml
proxy_app = "tcp://127.0.0.1:$((20008+(10*$i)))"
moniker = "$name.$i"
fast_sync = true
db_backend = "leveldb"
log_level = "state:info,*:error"

[rpc]
laddr = "tcp://0.0.0.0:$((20007+(10*$i)))"

[p2p]
laddr = "tcp://0.0.0.0:$((20006+(10*$i)))"
# connect to n randomly selected nodes (may contain self)
seeds = "`cat ../seeds.tmp | shuf | head -n 3 | paste -sd ","`"
# seeds = "`cat ../seeds.tmp | paste -sd ","`"
EOF
	cd -

	# continue with ethermint...

cat <<EOF > eth_genesis.json
{
    "config": {
        "chainId": 15,
        "homesteadBlock": 0,
        "eip155Block": 0,
        "eip158Block": 0
    },
    "nonce": "0xdeadbeefdeadbeef",
    "timestamp": "0x00",
    "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "mixhash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "difficulty": "0x40",
    "gasLimit": "0x8000000",
    "alloc": {
        "0x7eff122b94897ea5b0e2a9abf47b86337fafebdc": { "balance": "10000000000000000000000000000000000" },
        "0xc6713982649D9284ff56c32655a9ECcCDA78422A": { "balance": "10000000000000000000000000000000000" },
		`cat allocs.tmp | paste -sd ","`
    }
}
EOF

	ethermint --datadir $nodedir init eth_genesis.json
	cp ../eth_accounts/$i.json $nodedir/keystore/primary.json
done

popd
