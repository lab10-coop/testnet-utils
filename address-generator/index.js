/*
 * Takes one parameter: <nr of accounts to be created>
 * Creates the given number of Ethereum accounts and outputs them to stdout (json format)
 */

if (process.argv.length != 3) {
  console.log(`usage: node index.js <nr accounts>`);
  process.exit(1);
}

const nr_accounts = process.argv[2];

let Web3 = require('web3');
let web3 = new Web3(Web3.givenProvider);

let accs = []
for(let i=0; i<nr_accounts; i++) {
  acc = web3.eth.accounts.create();
//  console.log(JSON.stringify(acc));
  accs.push(acc)
}

console.log(JSON.stringify(accs, null, 2))

// in order to generate the addresses from the output, you may e.g do on cmdline:
// <command> | jq ".[].address"

