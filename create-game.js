require('dotenv').config();
const ethers = require('ethers');
const GameFactoryABI = require('./out/GameFactory.sol/GameFactory.json');

const GAME_FACTORY_ADDRESS = '0x85E433c027F2438375ce9eBA1C42A8CFFDC2CA5c';
const RPC_URL = 'https://spicy-rpc.chiliz.com/'; // Chiliz testnet RPC URL

async function createGame() {
    try {
      // Create a provider
      const provider = new ethers.JsonRpcProvider(RPC_URL);
  
      // Create a signer using the private key
      const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  
      // Create a contract instance
      const gameFactory = new ethers.Contract(GAME_FACTORY_ADDRESS, GameFactoryABI.abi, signer);
  
      // Check if the contract is deployed
      const code = await provider.getCode(GAME_FACTORY_ADDRESS);
      if (code === '0x') {
        throw new Error('GameFactory contract is not deployed at the specified address');
      }
  
      console.log("Contract is deployed at the specified address");
  
      // Check account balance
      const balance = await provider.getBalance(signer.address);
      console.log("Account balance:", ethers.formatEther(balance), "CHZ");
  
      // Create a random salt
      const salt = ethers.randomBytes(32);
      console.log("Generated salt:", ethers.hexlify(salt));
  
      // Try to get the future game address
      try {
        const futureGameAddress = await gameFactory.getGameAddress(salt);
        console.log("Predicted game address:", futureGameAddress);
      } catch (predictError) {
        console.error("Error predicting game address:", predictError);
      }
  
      // Encode the function call data
      const data = gameFactory.interface.encodeFunctionData('createGame', [salt]);
      console.log("Encoded function call data:", data);
  
      // Simulate the transaction
      console.log("Simulating transaction...");
      try {
        const result = await provider.call({
          to: GAME_FACTORY_ADDRESS,
          data: data,
          from: signer.address
        });
        console.log("Simulation result:", result);
      } catch (simulateError) {
        console.error("Error simulating transaction:", simulateError);
        if (simulateError.data) {
          try {
            const decodedError = gameFactory.interface.parseError(simulateError.data);
            console.error("Decoded error:", decodedError);
          } catch (decodeError) {
            console.error("Could not decode error data");
          }
        }
      }
  
      // Estimate gas with more detailed error handling
      console.log("Estimating gas...");
      try {
        const estimatedGas = await provider.estimateGas({
          to: GAME_FACTORY_ADDRESS,
          data: data,
          from: signer.address
        });
        console.log("Estimated gas:", estimatedGas.toString());
      } catch (estimateError) {
        console.error("Error estimating gas:", estimateError);
        if (estimateError.error && estimateError.error.message) {
          console.error("Revert reason:", estimateError.error.message);
        }
        return;
      }
  
      // Create the game
      console.log("Creating game...");
      const tx = await gameFactory.createGame(salt, {
        gasLimit: 3000000 // Increased gas limit
      });
      console.log("Transaction hash:", tx.hash);
  
      // Wait for the transaction to be mined
      const receipt = await tx.wait();
      console.log("Transaction confirmed in block:", receipt.blockNumber);
  
      // Find the GameCreated event
      const event = receipt.logs.find(
        log => log.topics[0] === ethers.id("GameCreated(address)")
      );
  
      if (event) {
        const gameAddress = ethers.dataSlice(event.data, 12);
        console.log("New game created at address:", gameAddress);
      } else {
        console.log("GameCreated event not found in the transaction logs");
      }
  
    } catch (error) {
      console.error("Error creating game:", error);
      if (error.reason) console.error("Error reason:", error.reason);
      if (error.code) console.error("Error code:", error.code);
      if (error.transaction) console.error("Error transaction:", error.transaction);
      if (error.receipt) console.error("Error receipt:", error.receipt);
    }
  }
  
  createGame();