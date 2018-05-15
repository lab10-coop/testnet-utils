# Tendermint+Ethermint Testnet

Contains scripts for easy setup and running of Tendermint+Ethermint testnets with arbitrary number of nodes.  
All nodes are run on the same host, thus the results can't be expected to well reflect the behaviour in real world scenarios.

## Running

Tested on Ubuntu 16.04

Required **dependencies**: jq  
(may require more, e.g. build-essential)

### To be run by root

`install_go.sh` adds a PPA and installs the package `golang-go`

### To be run by user

To be run once:  
`install_tendermint_and_ethermint.sh` completes the go install (setting env variables), then installs tendermint (v0.14.0) and ethermint from source. The binaries are copied to $GOBIN which is in $PATH.

To be run in order to create a new testnet:  
`init_testnet.sh <testnet name> <nr nodes>` creates a directory <testnet name> containing a data directory with genesis, config, keys etc. for every node. Templates for genesis and config are embedded in this script.  
Make sure the port range between 20010 and 20010 + (<nr nodes> * 10) is available.

To be run in order to start all nodes of a testnet:
`run_testnet.sh <testnet name>`  
Spawns a Tendermint and an Ethermint process per node, then waits for all processes to finish (which will usually not happen unless Ctrl-C is pressed).  
Reports died processes.

Every process has a dedicated logfile in <testnet name>/logs.  
E.g. for following the output of Tendermint process of node 3, do `tail +F <testnet name>/logs/tm3.log`.  
Note that when restarting the testnet, the logs will be overwritten.

`reset_testnet.sh <testnet name>` allows to reset an existing testnet. Keeps the config, but the chain is started from scratch on next run.   
Was necessary because of [this issue](https://github.com/tendermint/ethermint/issues/397) ([now fixed](https://github.com/d10r/ethermint/commit/92e9e94b51044be491cae93b2b4be1a60a7b96c6)).

### Interact

All nodes expose Ethereum's RPC and WS interface on localhost.  
In order to create an ssh tunnel to such an interface and launch a geth console, do (example for interacting with node 3):
`ssh -N root@artis.lab10.io -L 20031:localhost:20031`  
and in another terminal (or add param `-f` to ssh for backgrounding)  
`geth attach http://localhost:20031`

All nodes have a funded account with password *1234*. Thus in order to send a transaction, first unlock with  
`personal.unlockAccount(eth.accounts[0], "1234")`

Example for creating 100 simple transactions (transferring 100 wei each) in a loop (in geth console):  
`for (i=0; i<100; i++) { eth.sendTransaction({from: eth.accounts[0], to: "0x54717fdd2D61DDa38F60Cf822c225Fe65fC18e64", value: 100}) }`

### Load test

`fire_transactions.sh` creates random transactions and distributes them throughout the nodes of a testnet.  
For now the transactions are simple value transfers between external accounts (no contract calls / `data` field empty).  

Uses unix sockets (instead of the slower, but also remotely available TCP sockets) RPC interface.  
The transactions are sent to the nodes batched, that is, one write operation contains several txs.

Example invocation:  
`./fire_transactions.sh tm10 5 2`  
will send batches of 5 transaction, pausing for 2 seconds between batches.  
Since this will run in parallel for all testnet nodes, it would translate to 50 transactions every 2 seconds -> 25 transactions per second (this is ignoring the time it takes to write a batch to the socket, thus the actual throughput will be lower).  

In case we want to more accurately control the load, the implementation can be changed such that the time it takes to send the requests is subtracted from the waiting time.

`count_pending_txs.sh` can be used to monitor the number of pending transactions per testnet node (can vary, depending on the network topology).  
Example invocation:  
`count_pending_txs.sh tm10`.

## More

More information can be found on [this Wiki Page](https://wiki.lab10.io/pages/viewpage.action?pageId=329172).
