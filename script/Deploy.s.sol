// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.20;

// import "forge-std/Script.sol";
// import "../src/GameFactory.sol";
// import "../src/Game.sol";
// import "../src/GamePositions.sol";
// import "../src/Orderbook.sol";

// contract DeployScript is Script {
//     function run() external {
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
//         address deployer = vm.addr(deployerPrivateKey);
//         vm.startBroadcast(deployerPrivateKey);

//         // Deploy GameFactory
//         GameFactory gameFactory = new GameFactory();

//         // Set up game parameters
//         address resolver = deployer; // For simplicity, we're using the deployer as the resolver
//         uint40 expectedEnd = uint40(block.timestamp + 7 days);
//         string[] memory optionNames = new string[](2);
//         optionNames[0] = "Yes";
//         optionNames[1] = "No";

//         // Deploy Game directly (not using factory for simplicity)
//         Game game = new Game(
//             resolver,
//             expectedEnd,
//             optionNames
//         );

//         // Get the GamePositions contract address
//         GamePositions gamePositions = GamePositions(game.positions());

//         // Deploy Orderbook
//         OrderBook orderBook = new OrderBook(gamePositions);

//         vm.stopBroadcast();

//         // Log the deployed contract addresses
//         console.log("GameFactory deployed at:", address(gameFactory));
//         console.log("Game deployed at:", address(game));
//         console.log("GamePositions deployed at:", address(gamePositions));
//         console.log("OrderBook deployed at:", address(orderBook));
//     }
// }