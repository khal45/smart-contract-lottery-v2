// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test, CodeConstants {
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed player);

    Raffle public raffleContract;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    address PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffleContract, helperConfig, subscriptionId) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);

        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffleContract.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function testEntranceFeeIsEqualToConfigEntranceFee() public view {
        assertEq(raffleContract.getEntranceFee(), entranceFee);
    }

    function testIntervalIsEqualToConfigInterval() public view {
        assertEq(raffleContract.getInterval(), interval);
    }

    function testSubscriptionIdIsConfigSubscriptionId() public view {
        assertEq(raffleContract.getSubscriptionId(), subscriptionId);
    }

    function testVrfCoordinatorIsEqualToCOnfigVrfCoordinator() public view {
        assertEq(raffleContract.getVrfCoordinator(), vrfCoordinator);
    }

    function testGasLaneIsEqualToConfigGasLane() public view {
        assertEq(raffleContract.getGasLane(), gasLane);
    }

    function testCallbackGasLimitIsEqualToConfigCallbackGasLimit() public view {
        assertEq(raffleContract.getCallbackGasLimit(), callbackGasLimit);
    }

    function testLastTimeStampInitializesAsBlockTimeStamp() public view {
        assertEq(raffleContract.getLastTimeStamp(), block.timestamp);
    }

    function testRaffleShouldInitializeInOpenState() public view {
        assertEq(uint256(raffleContract.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
    }

    /*//////////////////////////////////////////////////////////////
                             ENTERRAFFLE
    //////////////////////////////////////////////////////////////*/

    function testRaffleRevertsIfYouDontPayEnoughEth() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__NeedMoreEthToEnterRaffle.selector, 0, entranceFee));
        raffleContract.enterRaffle();
        // Assert
    }

    function testCanNotEnterRaffleWhenRaffleCalculating() public raffleEntered {
        // Arrange (setup the necessary parameters for the test)
        raffleContract.performUpkeep("");
        // Act / assert (perform actions)
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffleContract.enterRaffle{value: entranceFee}();
        // Assert (verify action)
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // Arrange (setup the necessary parameters for the test)
        vm.prank(PLAYER);
        // Act (perform action)
        raffleContract.enterRaffle{value: entranceFee}();
        uint256 indexOfPlayer = raffleContract.getNumOfPlayers() - 1;
        // Assert (verify action)
        assertEq(raffleContract.getPlayer(indexOfPlayer), PLAYER);
    }

    function testRaffleEmitsEventWhenAPlayerEnters() public {
        // Arrange (setup the necessay parameters for the test)
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectEmit(true, false, false, false);
        emit RaffleEntered(PLAYER);
        raffleContract.enterRaffle{value: entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                             CHECKUPKEEP
    //////////////////////////////////////////////////////////////*/

    function testCheckUpKeepReturnsFalseIfTimeHasNotPassed() public {
        // Arrange (setup the necessary parameters for the test)
        vm.prank(PLAYER);
        raffleContract.enterRaffle{value: entranceFee}();
        // Act (perform function)
        (bool upKeepNeeded,) = raffleContract.checkUpkeep("");
        // Assert (verify action)
        assertEq(upKeepNeeded, false);
    }

    function testCheckUpKeepReturnsFalseIfRaffleIsCalculating() public raffleEntered {
        // Arrange (setup the necessary parameters for the test)
        raffleContract.performUpkeep("");
        // Act (perform function)
        (bool upKeepNeeded,) = raffleContract.checkUpkeep("");
        // Assert (verify action)
        assertEq(upKeepNeeded, false);
    }

    function testCheckUpKeepReturnsFalseIfRaffleHasNoBalance() public {
        // Arrange (setup the necessary parameters for the test)
        vm.prank(PLAYER);
        // Act (perform function)
        (bool upKeepNeeded,) = raffleContract.checkUpkeep("");
        // Assert (verify action)
        assertEq(upKeepNeeded, false);
    }

    function testCheckUpKeepReturnsFalseIfRaffleHasNoPlayers() public view {
        // Act (perform function)
        (bool upKeepNeeded,) = raffleContract.checkUpkeep("");
        // Assert (verify action)
        assertEq(upKeepNeeded, false);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() public raffleEntered {
        // Act (perform function)
        (bool upKeepNeeded,) = raffleContract.checkUpkeep("");
        // Assert (verify action)
        assertEq(upKeepNeeded, true);
    }

    /*//////////////////////////////////////////////////////////////
                             PERFORMUPKEEP
    //////////////////////////////////////////////////////////////*/
    function testPerformUpkeepCanOnlyRunIfCheckUpKeepIsTrue() public raffleEntered {
        // Act / Assert
        raffleContract.performUpkeep("");
    }

    function testPerformUpKeepRevertsIfUpKeepNotNeeded() public {
        // Arrange (setup the necessary parameters for the test)
        vm.prank(PLAYER);
        raffleContract.enterRaffle{value: entranceFee}();
        // Act (perform function)
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpKeepNotNeeded.selector,
                address(raffleContract).balance,
                raffleContract.getNumOfPlayers(),
                uint256(raffleContract.getRaffleState())
            )
        );
        raffleContract.performUpkeep("");
        // Assert (verify action)
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        // Act (perform actions)
        vm.recordLogs();
        raffleContract.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        // Assert (verify actions)
        Raffle.RaffleState raffleState = raffleContract.getRaffleState();
        assertGt(uint256(requestId), 0);
        assertEq(uint256(raffleState), 1);
    }

    /*//////////////////////////////////////////////////////////////
                           FULFILLRANDOMWORDS
    //////////////////////////////////////////////////////////////*/
    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        raffleEntered
        skipFork
    {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffleContract));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered skipFork {
        // Arrange (set up the necessary parameters)
        uint256 additionalEntrants = 3; // 4 total players
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            // address newPlayer = vm.addr(i);
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffleContract.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimeStamp = raffleContract.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act (perform action)
        vm.recordLogs();
        raffleContract.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffleContract));

        // Assert (verify action)
        address recentWinner = raffleContract.getRecentWinner();
        Raffle.RaffleState raffleState = raffleContract.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffleContract.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assertEq(recentWinner, expectedWinner);
        assertEq(uint256(raffleState), uint256(Raffle.RaffleState.OPEN));
        assertEq(winnerBalance, winnerStartingBalance + prize);
        assertGt(endingTimeStamp, startingTimeStamp);
    }

    function testFulfillRandomWordsRevertsIfPayingWinnerIsUnsuccessfull() public raffleEntered {}
}
