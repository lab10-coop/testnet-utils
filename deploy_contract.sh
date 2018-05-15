#!/bin/bash

# usage: $0 <contract source file> [<test function call>]
# Example: $0 Sometoken.sol "totalSupply()"
# You should use a test which isn't expected to return 0 / the default value.
# Note that the RPC port is currently hardcoded, see variable "rpc_host" below.
#
# requires solc and jq installed
#
# CAUTION: This currently fails for huge (?) contracts, e.g. BasicStreems.sol.
# In this case, it deploys the contract without error, but the test fails ("totalSupply()" returns 0) for yet unknown reasons.

set -u
set -e

contract=$1
if [ ! -z ${2+x} ]; then
  testcall=$2
fi

rpc_host="http://localhost:8545"
ethexec="geth attach $rpc_host --exec"

mkdir -p tmp
rm tmp/*
solc --overwrite --optimize --output tmp --bin --abi $contract

if [[ `ls tmp/*.abi | wc -l` != 1 ]]; then
  echo "currently only single-contract files are supported"
fi

abi="`cat tmp/*.abi`"
bin='"0x'`cat tmp/*.bin`'"'

#contract_metadata="BasicStreems.json"
#abi=`cat $contract_metadata | jq --compact-output ".abi"`
#bin=`cat $contract_metadata | jq --compact-output ".bytecode"`

echo "abi: $abi"

txHash=`$ethexec "
{
  var C = web3.eth.contract($abi)
  var instance = C.new(web3.toWei(1000000000), { data: $bin, from: eth.accounts[0] })
  var txHash = instance.transactionHash
  txHash

  // this doesn't work because execution stops when reaching the end (ignoring set timeout) / doesn't execute the timeout handler when busy waiting
  /*
  var canExit = false
  function pollContractAddress() {
    setTimeout(function() {
      txReceipt = eth.getTransactionReceipt(txHash)
       if(txReceipt) {
	var addr = txReceipt.address
        console.log('contract address is ' + addr) 
        canExit = true
      } else {
        pollContractAddress()
      }
    }, 1000)
  }
  pollContractAddress()
  while(! canExit) {}
  */
}"`

echo "txHash: $txHash"
echo "waiting for the transaction to be included in a block..."

# busy wait for execution (poll every second)
while true; do
  addr=`$ethexec "
  {
    if(eth.getTransactionReceipt($txHash)) {
      eth.getTransactionReceipt($txHash).contractAddress
    }
  }"`
  if [[ $addr != "undefined" ]]; then
    echo "The contract address is: $addr"

    # quick test drive
    if [ ! -z ${testcall+x} ]; then
      echo "Testing with call $testcall..."
      $ethexec "
      {
        var C = web3.eth.contract($abi)
        var instance = C.at($addr)
	instance.$testcall
      }"
    fi
    break
  fi
  sleep 1
done

exit



# cmds for manually deploy contract (check rpc port!):
#bin=`cat $contract_metadata | jq --compact-output ".bytecode"`
#geth attach --exec "{ eth.sendTransaction({from: eth.accounts[0], data: $bin}) }" http://localhost:50007
#geth attach --exec "{ eth.getTransactionReceipt(<txHash>).contractAddress }" http://localhost:50007

# for more complex JS scripts, you can also create a file in-place:
#geth attach "http://localhost:50007" --exec `cat << EOF
#console.log('hello there');
#console.log('hello again');
#EOF`

