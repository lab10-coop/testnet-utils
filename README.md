# About

This is a collection of tools for deploying, running and otherwise tampering with testnets.
It contains scripts for various kinds of testnets:
* [Ethermint](http://ethermint.readthedocs.io/)
* Parity with [Aura consensus](https://github.com/paritytech/parity/wiki/Aura)
* Parity with (built-in) Tendermint consensus

The most important scripts are:

**init_testnet.sh**: takes a *name* and the *number of nodes* as parameters, prepares a directory with that name which contains the initial state of such a testnet - including a sub-directory for every node (contains keys genesis etc.).
Chain and node config templates are embedded in this script.

**run_testnet.sh**: takes a name (directory representing a testnet), runs that testnet by starting a process for every node (in case of Ethermint 2 processes per node) according to it's config.

**For more details, take look at the Readme for Ethermint.**
The setups for Parity are derived (copied, pasted & adapted) from that and don't have a dedicated Readme (since they're so similar).
Note that the the Parity configs have the fist node hardcoded (`node0.tmpl`), because that was convenient.
In case you use any of those, you may need to change some hardcoded addresses which point to ARTIS infrastructure.

Several accounts (incl. private keys) are included for convenience. Better don't use them for a public testnet.
