// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./GamePositions.sol";

contract Game {
    struct PlayerBet {
        string optionName;
        uint amount;
    }

    struct GameStatus {
        address resolver;
        uint40 expectedEnd;
        bool resolved;
        string winningOption;
        mapping(string => uint) optionTotalStakes;
    }

    GameStatus public status;
    mapping(address => PlayerBet) public playerBets;
    mapping(address => bool) public hasClaimedReward;
    GamePositions public positions;
    string[] public options;

    event OptionPicked(address indexed player, string optionName, uint amount);
    event GameResolved(string winningOption);
    event RewardClaimed(address indexed player, uint amount);

    error GameOptionDoesNotExist();
    error GameAlreadyResolved();
    error UnauthorizedResolver();
    error InvalidWinningOption();
    error NoBetPlaced();
    error RewardAlreadyClaimed();
    error GameNotFinished();

    constructor(
        address resolver,
        uint40 expectedEnd
    ) {
        positions = new GamePositions();

        status.resolver = resolver;
        status.expectedEnd = expectedEnd;
        status.resolved = false;

        options = ["Yes", "No"];
        status.optionTotalStakes["Yes"] = 0;
        status.optionTotalStakes["No"] = 0;
    }

    function pickOption(string memory optionName) external payable {
        if (!_isValidOption(optionName)) revert GameOptionDoesNotExist();
        if (block.timestamp > status.expectedEnd) revert GameNotFinished();

        uint amount = msg.value;
        positions.mint(msg.sender, optionName, amount);

        playerBets[msg.sender] = PlayerBet(optionName, amount);
        status.optionTotalStakes[optionName] += amount;

        emit OptionPicked(msg.sender, optionName, amount);
    }

    function resolveGame(string memory winningOption) external {
        if (msg.sender != status.resolver) revert UnauthorizedResolver();
        if (status.resolved) revert GameAlreadyResolved();
        if (!_isValidOption(winningOption)) revert InvalidWinningOption();

        status.resolved = true;
        status.winningOption = winningOption;

        string memory losingOption = keccak256(bytes(winningOption)) == keccak256(bytes("Yes")) ? "No" : "Yes";
        positions.burn(address(this), losingOption, status.optionTotalStakes[losingOption]);

        emit GameResolved(winningOption);
    }

    function claimReward() external {
        if (!status.resolved) revert GameNotFinished();
        PlayerBet storage playerBet = playerBets[msg.sender];
        if (playerBet.amount == 0) revert NoBetPlaced();
        if (hasClaimedReward[msg.sender]) revert RewardAlreadyClaimed();

        if (keccak256(bytes(playerBet.optionName)) != keccak256(bytes(status.winningOption))) {
            hasClaimedReward[msg.sender] = true;
            emit RewardClaimed(msg.sender, 0);
            return;
        }

        uint reward = (playerBet.amount * address(this).balance) / status.optionTotalStakes[status.winningOption];
        hasClaimedReward[msg.sender] = true;
        payable(msg.sender).transfer(reward);

        emit RewardClaimed(msg.sender, reward);
    }

    function hasGameEnded() public view returns (bool) {
        return block.timestamp > status.expectedEnd;
    }

    function getTotalPool() public view returns (uint) {
        return address(this).balance;
    }

    function getOptionNames() external view returns (string[] memory) {
        return options;
    }

    function _isValidOption(string memory optionName) internal pure returns (bool) {
        return keccak256(bytes(optionName)) == keccak256(bytes("Yes")) || 
               keccak256(bytes(optionName)) == keccak256(bytes("No"));
    }
}