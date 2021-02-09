const fs = require('fs');
const Web3 = require('web3');
const BN = require('bn.js');
var Contract = require('web3-eth-contract');
const tx = require('ethereumjs-tx')

HMY_TESTNET_RPC_URL = 'https://api.s0.b.hmny.io';

const web3 = new Web3(HMY_TESTNET_RPC_URL);


const simpleTest = async () => {
    const contract_address = "0x622E9e164f7cF73e7633e7BF2F276805baEA3744";
    const abi = JSON.parse(fs.readFileSync('./NFTSale.abi', 'utf8'));
    var contract_interface = new web3.eth.Contract(abi,contract_address,{
     from: "0x01bd3a404d88A2162AAe15D11BB8F2cc13d13d30",
     gasPrice: '1000000000'   
    });

    console.log(contract_interface);

    const tx = {
    from: '0x3088a801d90f0b79cb5ffb634fc9a7591d26a295',
    to: '0x622E9e164f7cF73e7633e7BF2F276805baEA3744',
    value: 100,
    gasPrice: '1000000000',  
    gas: '6721900', 
    data: contract_interface.methods.purchaseToken(4996).encodeABI() 
    };

    const privateKey = '0xc25647a02107697bdcc404152cbde4330b4acbc8e5f834434e46f9ed75953b90';
    const signPromise = web3.eth.accounts.signTransaction(tx, privateKey);
	
    signPromise.then((signedTx) => {
  	// raw transaction string may be available in .raw or 
  	// .rawTransaction depending on which signTransaction
  	// function was called
  	const sentTx = web3.eth.sendSignedTransaction(signedTx.raw || signedTx.rawTransaction);
  	sentTx.on("receipt", receipt => {
    	// do something when receipt comes back
  	console.log("YAAY, Success");
	});
  sentTx.on("error", err => {
	console.log(err);
  });
}).catch((err) => {
  	console.log(err);
	// do something when promise fails
});    

};

simpleTest();
