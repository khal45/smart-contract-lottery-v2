// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Vm} from "forge-std/Vm.sol";

contract InteractionsTest is Test, CodeConstants {
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed player);

    Raffle public raffleContract;
    HelperConfig public helperConfig;
    uint256 public constant STARTING_PLAYER_BALANCE = 1 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffleContract, helperConfig, subscriptionId) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        // subscriptionId = config.subscriptionId;
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testPlayersCanEnterRaffleAndWinnerPickedIsPayedCorrectly() public skipFork {
        // Arrange (setup necessary parameters for the test)
        uint256 numOfPlayers = 10;
        /**
         * @dev For loop to create 10 players to enter the raffle
         */
        for (uint256 i = 1; i <= numOfPlayers; i++) {
            address newPlayer = vm.addr(i);
            hoax(newPlayer, STARTING_PLAYER_BALANCE);
            raffleContract.enterRaffle{value: entranceFee}();
        }
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        uint256 prize = entranceFee * numOfPlayers;

        /**
         * @dev Balance of the player after entering the raffle
         */
        uint256 startingPlayerBalance = STARTING_PLAYER_BALANCE - entranceFee;

        // Act (perform actions)
        vm.recordLogs();
        raffleContract.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffleContract));

        Vm.Log[] memory allEntries = vm.getRecordedLogs();
        address winner = raffleContract.getRecentWinner();
        uint256 winnerEndingBalance = winner.balance;
        uint256 raffleState = uint256(raffleContract.getRaffleState());
        bytes32 expectedTopic = keccak256("WinnerPicked(address)");
        bool winnerEventFound = false;
        for (uint256 i = 0; i < allEntries.length; i++) {
            if (
                allEntries[i].topics[0] == expectedTopic && address(uint160(uint256(allEntries[i].topics[1]))) == winner
            ) {
                winnerEventFound = true;
                break;
            }
        }

        // Assert (verify actions)
        assertTrue(winnerEventFound, "WinnerPicked event not emitted or emitted with wrong address");
        assertEq(raffleState, 0);
        assertEq(winnerEndingBalance, startingPlayerBalance + prize);
    }
}
