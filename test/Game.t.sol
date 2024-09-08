// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Game.sol";
import "../src/GamePositions.sol";
import "../src/Orderbook.sol";

contract GameTest is Test {
    Game game;
    GamePositions gamePositions;
    OrderBook orderBook;
    address resolver;
    address player1 = address(2);
    address player2 = address(3);
    uint40 expectedEnd;
    string[] optionNames = ["Yes", "No"];

    function setUp() public {
        resolver = address(this);
        expectedEnd = uint40(block.timestamp + 7 days);

        // Deploy Game
        game = new Game(resolver, expectedEnd);

        // Get GamePositions address
        gamePositions = GamePositions(game.positions());

        // Deploy OrderBook
        orderBook = new OrderBook(gamePositions);

        // Fund player1 and player2 with some ether
        vm.deal(player1, 10 ether);
        vm.deal(player2, 10 ether);
    }

    function testConstructor() public {
        (address resolverAddress, uint40 endTime, bool isResolved, string memory winningOpt) = game.status();
        assertEq(resolverAddress, resolver);
        assertEq(endTime, expectedEnd);
        assertFalse(isResolved);
        assertEq(game.getOptionNames().length, 2);
    }

    function testPickOption() public {
        vm.prank(player1);
        game.pickOption{value: 1 ether}("Yes");

        (string memory optionName, uint amount) = game.playerBets(player1);
        assertEq(optionName, "Yes");
        assertEq(amount, 1 ether);
    }

    function testResolveGame() public {
        vm.prank(player1);
        game.pickOption{value: 1 ether}("Yes");

        game.resolveGame("Yes");

        (,, bool isResolved, string memory winningOption) = game.status();
        assertTrue(isResolved);
        assertEq(winningOption, "Yes");
    }

    function testClaimReward() public {
        vm.prank(player1);
        game.pickOption{value: 1 ether}("Yes");

        vm.prank(player2);
        game.pickOption{value: 1 ether}("No");

        game.resolveGame("Yes");

        vm.prank(player1);
        uint balanceBefore = player1.balance;
        game.claimReward();
        uint balanceAfter = player1.balance;

        assertEq(balanceAfter - balanceBefore, 2 ether);
    }

    function testClaimRewardLoser() public {
        vm.prank(player1);
        game.pickOption{value: 1 ether}("Yes");

        vm.prank(player2);
        game.pickOption{value: 1 ether}("No");

        game.resolveGame("No");

        vm.prank(player1);
        uint balanceBefore = player1.balance;
        game.claimReward();
        uint balanceAfter = player1.balance;

        assertEq(balanceAfter, balanceBefore);
    }

    function testHasGameEnded() public {
        assertFalse(game.hasGameEnded());

        vm.warp(expectedEnd + 1);
        assertTrue(game.hasGameEnded());
    }

    function testGetTotalPool() public {
        assertEq(game.getTotalPool(), 0);

        vm.prank(player1);
        game.pickOption{value: 1 ether}("Yes");

        vm.prank(player2);
        game.pickOption{value: 2 ether}("No");

        assertEq(game.getTotalPool(), 3 ether);
    }

    // Add more tests for GamePositions and OrderBook interactions if needed
}