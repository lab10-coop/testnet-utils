#!/bin/bash

# usage: $0 <testnet name> <nr nodes>
# requires jq to be installed: apt install jq
# max 100 nodes supported

set -e
set -u

name=$1
# -1 because there's already the bootnode (node0)
nr_nodes=$(($2-1))

if [[ ! -d $name ]]; then
	echo "creating $name..."
	mkdir -p $name
fi

pushd $name

# we won't silently overwrite an existing chain spec
if [[ -f chain.json ]]; then
	echo "file chain.json already exists. Delete if you really want to create a new one! Aborting."
	exit 1
fi

cp -a "../node0.tmpl" "node0"

echo $nr_nodes > nr_nodes

# accounts and address list were pre-created with
# for i in $(seq 100); do geth --keystore . account new --password <( echo "" ) --lightkdf && mv UTC* accounts/validator_$i.json; done
# for i in $(seq 100); do cat accounts/validator_$i.json | jq -r ".address" | cat <( echo -n 0x ) - >> validators; done

for v in `cat ../validators | head -n $nr_nodes`; do echo \"$v\"; done | paste -sd "," > validators.tmp

# Create the chain spec. Byzantium based (validator list varies)
cat <<EOF >> chain.json
{
	"name": "t2",
	"engine": {
		"tendermint": {
			"params": {
				"validators" : {
					"list": [
						"0xf8d232e2f75cca230b48c390854ea0c1c92705c5",
						`cat validators.tmp`
					]
				},
				"timeoutPropose": 2000,
				"timeoutPrevote": 2000,
				"timeoutPrecommit": 2000,
				"timeoutCommit": 2000
			}
		}
	},
	"genesis": {
		"seal": {
			"tendermint": {
				"round": "0x0",
				"proposal": "0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"precommits": [
					"0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
				]
			}
		},
		"difficulty": "0x20000",
		"gasLimit": "0x2FAF080",
		"author": "0xdeadbeef00000000000000000000000000000000"
	},
	"params": {
		"networkID": "0x4955",
		"maximumExtraDataSize": "0x20",
		"minGasLimit": "0x2FAF080",
		"gasLimitBoundDivisor": "0x400",
		"wasm": true,
		"eip140Transition": 0,
		"eip211Transition": 0,
		"eip214Transition": 0,
		"eip658Transition": 0
	},
	"accounts": {
		"0x0000000000000000000000000000000000000001": { "balance": "1", "builtin": { "name": "ecrecover", "pricing": { "linear": { "base": 3000, "word": 0 } } } },
		"0x0000000000000000000000000000000000000002": { "balance": "1", "builtin": { "name": "sha256", "pricing": { "linear": { "base": 60, "word": 12 } } } },
		"0x0000000000000000000000000000000000000003": { "balance": "1", "builtin": { "name": "ripemd160", "pricing": { "linear": { "base": 600, "word": 120 } } } },
		"0x0000000000000000000000000000000000000004": { "balance": "1", "builtin": { "name": "identity", "pricing": { "linear": { "base": 15, "word": 3 } } } },
		"0x0000000000000000000000000000000000000005": { "builtin": { "name": "modexp", "activate_at": 0, "pricing": { "modexp": { "divisor": 20 } } } },
		"0x0000000000000000000000000000000000000006": { "builtin": { "name": "alt_bn128_add", "activate_at": 0, "pricing": { "linear": { "base": 500, "word": 0 } } } },
		"0x0000000000000000000000000000000000000007": { "builtin": { "name": "alt_bn128_mul", "activate_at": 0, "pricing": { "linear": { "base": 40000, "word": 0 } } } },
		"0x0000000000000000000000000000000000000008": { "builtin": { "name": "alt_bn128_pairing", "activate_at": 0, "pricing": { "alt_bn128_pairing": { "base": 100000, "pair": 80000 } } } },

		"0xdac8cc8fe0a88a93ad1fae910fdffd2c6187724e": {
			"balance": "1000000000000000000000000000"
		}
	},
	"nodes": [
	]
}
EOF

# now initialize a data directory per node (-1 because there's already a bootnode)
for i in $(seq 1 $nr_nodes); do
	nodedir="node$i"
	echo "initializing $nodedir"
	mkdir -p $nodedir/keys/t2

	cp ../accounts/validator_$i.json $nodedir/keys/t2/validator.json
	addr=$(cat ../accounts/validator_$i.json | jq -r ".address" | cat <( echo -n 0x ) -)

	cd $nodedir

# config doc: https://wiki.parity.io/Configuring-Parity.html#config-file
# every node shifts the ports by 10. E.g. for node1, proxy_app port will be 20018, for node2 20028, for node399 23998 etc.
cat <<EOF >> config.toml
[parity]
base_path = "$nodedir"
chain = "chain.json"
identity = "$name.$i"

[account]
# unlock account for validation and account for ATS distribution
unlock = ["$addr"]
password = ["../pass"]

[ui]
disable=true

[network]
port = $((40006+(10*$i)))
max_peers = 200
discovery = true
bootnodes = ["enode://ae3612ef228780d16a6e0a43fb9a05755972b5b6f23f8a95973a83330ffa5671c85361505ea866f920961e98a5395fab8a58be95d04ab82a68293ccc9f77ab1f@127.0.0.1:40006"]

[rpc]
port=$((40007+(10*$i)))
# enables connecting through ssh tunnel (with remote mapping to different port)
hosts = ["all"]

[websockets]
disable = true

[dapps]
disable=true

[mining]
engine_signer = "$addr"
force_sealing = true

[misc]
log_file = "$nodedir/parity.log"
color = true
EOF
	cd -
done

popd
