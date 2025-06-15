// Order of layout
// Contract elements should be laid out in the following order:
// Pragma statements
// Import statements
// Events
// Errors
// Interfaces
// Libraries
// Contracts
// Inside each contract, library or interface, use the following order:
// Type declarations
// State variables
// Events
// Errors
// Modifiers
// Functions

// Order of functions
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/* Imports */
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

/**
 * @title A sample Raffle smart contract
 * @author khal45
 * @notice This contract is used for creating a sample raffle
 * @dev Implements chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /* Type Declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* State Variables */
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;
    address private immutable i_vrfCoordinator;
    uint256 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    address private s_recentWinner;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed player);
    event RequestedRandomWinner(uint256 indexed requesId);

    /* Errors */
    error Raffle__NeedMoreEthToEnterRaffle(uint256 value, uint256 entranceFee);
    error Raffle__RaffleNotOpen();
    // error Raffle__RaffleIsOpen(RaffleState raffleState);
    error Raffle__FailedToPayWinner(address winner, uint256 amount);
    error Raffle__UpKeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = vrfCoordinator;
        i_subscriptionId = subscriptionId;
        i_keyHash = gasLane;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {
        // Checks (verify all conditions)
        if (msg.value < i_entranceFee) {
            revert Raffle__NeedMoreEthToEnterRaffle(msg.value, i_entranceFee);
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        // Effects (modify internal state)
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);

        // Interactions (perform external interactions)
    }

    /**
     * @dev This is the function the chainlink nodes will call to determine if a winner is needed
     * The following should be true in order for upKeepNeeded to be true:
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH
     * 4. Implicitly, your subsription has LINK
     * @param -ignored
     * @return upKeepNeeded -true only if it's time to start the lottery
     * @return -ignored
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        override
        returns (bool upKeepNeeded, bytes memory /* performData */ )
    {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upKeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upKeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */ ) external override {
        /**
         * Generate a random number
         * Select a winner based on the random number
         * Should be automatically called
         */

        // Checks (verify all conditions)
        /**
         * @dev Checks whether upkeep is needed and reverts if it's not
         */
        (bool upKeepNeeded,) = checkUpkeep("");
        if (!upKeepNeeded) {
            revert Raffle__UpKeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        // Effects (modify internal state)
        s_raffleState = RaffleState.CALCULATING;

        // Interactions (perform external interactions)
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRandomWinner(requestId);
    }

    /**
     * @dev This is the function that Chainlink VRF node
     * calls to send the money to the random winner.
     */
    function fulfillRandomWords(
        uint256,
        /*requestId*/
        uint256[] calldata randomWords
    ) internal override {
        // Checks (verify all conditions)
        // Effects (modify internal state)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        // Interactions (perform external interactions)
        (bool success,) = s_recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__FailedToPayWinner(s_recentWinner, address(this).balance);
        }
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getInterval() external view returns (uint256) {
        return i_interval;
    }

    function getVrfCoordinator() external view returns (address) {
        return i_vrfCoordinator;
    }

    function getPlayer(uint256 indexOfPlayer) public view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getNumOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getSubscriptionId() external view returns (uint256) {
        return i_subscriptionId;
    }

    function getRequestConfirmations() external pure returns (uint16) {
        return REQUEST_CONFIRMATIONS;
    }

    function getNumWords() external pure returns (uint32) {
        return NUM_WORDS;
    }

    function getGasLane() external view returns (bytes32) {
        return i_keyHash;
    }

    function getCallbackGasLimit() external view returns (uint32) {
        return i_callbackGasLimit;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
