// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// enum ZodiakSign {
//     WheelTicket(0)
//     Aries(1),>
//     Taurus(2),
//     Gemini(3),
//     Cancer(4),
//     Leo(5),
//     Virgo (6),
//     Libra (7),
//     Scorpio (8),
//     Sagittarius (9),
//     Capricorn (10),
//     Aquarius (11),
//     Pisces (12),
//     WinningUndisclosed (13),
//     Prize1 (14),
//     Prize2 (15),
//     Prize3 (16),
//     Prize4 (17),
//     Prize5 (18),
// }

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ZodiakNFT} from "./ZodiakNFT.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

error IncorrectAmount(uint256 amountSent, uint256 amountRequired);
error InvalidId(uint256 id);
error CannotTallyPool();
error NoWinningTickets();
error CannotSkimPool();
error CannotSpinTheWheel();
error InsufficientBalance();
error CannotCreateNewPool();
error RequestAlreadyFulfilled();

contract ZodiakLottery is VRFConsumerBaseV2Plus {
    ZodiakNFT public immutable ZDK; //ZodiakNFT contract
    address immutable COSMIC_VAULT; //The holder of money for easier accountability.
    uint256 constant WHEEL_TICKET = 0; //the id of the wheel ticket
    uint256 constant WINNING_TOKEN_ID = 13; //the id of the winning undisclosed token
    uint256 ticketPrice = 0.01 ether;
    Pool[] public lotteryPools;
    mapping(uint256 requestID => RequestVRF request) public requests;
    mapping(address => mapping(uint256 => uint256[5])) public userWinningTickets; // 0 = 1st prize, 1 = 2nd prize, 2 = 3rd prize, 3 = 4th prize, 4 = 5th prize

    //CHECK: use packing
    struct Pool {
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 pot;
        uint256 remainingPot;
        uint256 numberOfWinningTickets;
        uint256 tier1; //total amount for 1 winner
        uint256 tier2;
        uint256 tier3;
        uint256 tier4; //total amount to be shared among prize winners
        uint256 tier5;
        uint256[5] winningTicketsRemaining; // 0 = 1st prize, 1 = 2nd prize, 2 = 3rd prize, 3 = 4th prize, 4 = 5th prize
        uint256[2] totalPrizeTickets_4_5; // 0 = prize 4, 1 = prize 5
        uint256 unusedPrizeTickets;
    }

    struct RequestVRF {
        uint256 zodiakChoice;
        uint256 poolId;
        bool isSpin;
        bool fulfilled;
        address requester;
    }

    //TODO: hardcoded now, replace for production
    //CHAINLINK VARIABLES
    IVRFCoordinatorV2Plus COORDINATOR;
    address constant SEPOLIA_VRF_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    uint256 s_subscriptionId = 20406656112607748875103932091356574480957515311019163390203649607360869579051;
    bytes32 keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 callbackGasLimit = 800000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;

    event Testing(uint256 num1, uint256 num2);

    constructor(address _theMighty, address _cosmicVault) VRFConsumerBaseV2Plus(SEPOLIA_VRF_COORDINATOR) {
        COSMIC_VAULT = _cosmicVault;
        COORDINATOR = IVRFCoordinatorV2Plus(SEPOLIA_VRF_COORDINATOR);
        lotteryPools.push(Pool(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, [uint256(0), 0, 0, 0, 0], [uint256(0), 0], 0));
        ZDK = new ZodiakNFT("https://zodiaknft.com/", _theMighty);
    }

    function createTicket(uint256 _amount) external payable {
        if (msg.value < 0.01 ether * _amount) {
            revert IncorrectAmount(msg.value, 0.01 ether * _amount);
        }
        ZDK.createTicket(_amount, msg.sender);
    }

    /**
     * @dev tally the pool and do rewards accounting
     */
    function tallyPool() external {
        Pool memory currentPoolM = lotteryPools[lotteryPools.length - 1];
        Pool storage currentPoolS = lotteryPools[lotteryPools.length - 1];

        //errors
        if (block.timestamp < currentPoolM.endTimestamp) {
            revert CannotTallyPool();
        }
        if (currentPoolM.numberOfWinningTickets == 0) {
            revert CannotTallyPool();
        }

        // calculate and transfer fees for the house before distributing the pot
        uint256 fees = (currentPoolM.pot * 10) / 100;

        currentPoolS.pot = currentPoolM.pot = currentPoolM.pot - fees;
        currentPoolS.tier1 = (currentPoolM.pot * 25) / 100;
        currentPoolS.tier2 = (currentPoolM.pot * 10) / 100;
        currentPoolS.tier3 = (currentPoolM.pot * 5) / 100;
        currentPoolS.tier4 = (currentPoolM.pot * 20) / 100;
        currentPoolS.tier5 = (currentPoolM.pot * 40) / 100;
        currentPoolS.winningTicketsRemaining =
            [1, 1, 1, currentPoolM.totalPrizeTickets_4_5[0], currentPoolM.totalPrizeTickets_4_5[1]];
        //WARNING: cosmic vault not implemented , should have bookkeeping
        payable(COSMIC_VAULT).transfer(fees);
    }

    //TODO: restrict to authorized
    /**
     * @dev skim the funds of a fully redeemed pool
     */
    function skimPool(uint256 _poolId) external {
        if (block.timestamp < lotteryPools[_poolId].endTimestamp) {
            revert CannotSkimPool();
        }
        //TODO: maybe instead of just transfering, it can be allocated (to a new pool? for other things?)
        payable(COSMIC_VAULT).transfer(lotteryPools[_poolId].remainingPot);
    }

    /**
     * @dev triggers VRF callback that will launch the spin of the wheel
     * @param _zodiakChoice the zodiak booster of choice in case of loss
     */
    function launchSpin(uint256 _zodiakChoice) external {
        if(block.timestamp > lotteryPools[lotteryPools.length - 1].endTimestamp){
            revert CannotSpinTheWheel();
        }
        if (ZDK.balanceOf(msg.sender, WHEEL_TICKET) < 1) {
            revert InsufficientBalance();
        }
        if (_zodiakChoice < 1 || _zodiakChoice >= WINNING_TOKEN_ID) {
            revert InvalidId(_zodiakChoice);
        }

        uint256 requestID = requestRandomWords();

        requests[requestID].zodiakChoice = _zodiakChoice;
        requests[requestID].isSpin = true;
        requests[requestID].requester = msg.sender;
    }

    /**
     * @dev for winning ticket holders to reveal their prize ticket
     * @dev triggers VRF for RNG callback, that will start the reveal of the prize ticket
     * @param _poolId the id of the pool to reveal the prize ticket from
     */
    function launchReveal(uint256 _poolId) external {
        if (ZDK.balanceOf(msg.sender, WINNING_TOKEN_ID) < 1) {
            revert InsufficientBalance();
        }

        uint256 requestID = requestRandomWords();

        requests[requestID].poolId = _poolId;
        requests[requestID].requester = msg.sender;
    }

    /**
     * @dev Request randomness
     * @return requestId The ID of the request sent to the VRF Coordinator
     */
    function requestRandomWords() public returns (uint256 requestId) {
        // Will revert if subscription is not set and funded.
        // To enable payment in native tokens, set nativePayment to true.
        requestId = COORDINATOR.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
    }

    //TODO: restrict to authorized
    /**
     * @dev Create a new pool
     */
    function createPool() public {
        if (block.timestamp < lotteryPools[lotteryPools.length - 1].endTimestamp) {
            revert CannotCreateNewPool();
        }
        Pool memory newPool;
        newPool.startTimestamp = block.timestamp;
        newPool.endTimestamp = block.timestamp + 3 hours;
        lotteryPools.push(newPool);
    }

    /**
     * @dev Set the price of the wheel spinning ticket
     * @param _price the price of the NFT
     */
    function setPrice(uint256 _price) public {
        ticketPrice = _price;
    }

    //Internal function called on VRF callback
    /**
     * @dev on VRF callback spins the wheel and mutate the token into the winning ticket or the zodiak booster of choice
     * @param _zodiakChoice the zodiak booster of choice
     * @param _randomWord the random number generated by the VRF
     * @param _owner the owner of the NFT
     * @return win true if the user wins, false if the user looses
     */
    function spinTheWheel(uint256 _zodiakChoice, uint256 _randomWord, address _owner) internal returns (bool win) {
        //When the wheel is spinned, the price of a ticket is added to the pot
        lotteryPools[lotteryPools.length - 1].pot += 0.01 ether;

        //get a random number between 0 and 100
        uint256 RNG = _randomWord % 101;

        //win or loose
        if (RNG < 12) {
            //make sure the number of winning tickets of a the current pool is accounted for
            lotteryPools[lotteryPools.length - 1].numberOfWinningTickets++;
            lotteryPools[lotteryPools.length - 1].unusedPrizeTickets++;
            win = true;

            // win: mutate the token into winning ticket
            ZDK.cosmicMutation(WHEEL_TICKET, WINNING_TOKEN_ID, _owner);
        } else {
            win = false;
            //lose: mutate the token into the zodiak booster of choice
            ZDK.cosmicMutation(WHEEL_TICKET, _zodiakChoice, _owner);
        }
    }

    //TODO: cache lotteryPools[_poolId] for lot of gas savings
    //TODO: complex function, check all security and logic thoroughly
    //TODO: odds values should be variables
    //Internal function called on VRF callback
    /**
     * @dev on VRF callback reveals the prize ticket
     * @param _poolId the id of the pool to reveal the prize ticket from
     * @param _randomWord the random number generated by the VRF
     * @return prizeTokenId the id of the prize token
     */
    function revealPrize(uint256 _poolId, uint256 _randomWord, address _user) internal returns (uint256 prizeTokenId) {
        //get a random number between 0 and 100
        uint256 RNG = _randomWord % 101;

        if (RNG <= 10) {
            if (lotteryPools[_poolId].winningTicketsRemaining[0] == 1) {
                prizeTokenId = 14;
                userWinningTickets[_user][lotteryPools.length - 1][0]++;
                lotteryPools[_poolId].winningTicketsRemaining[0]--;
            } else {
                prizeTokenId = 15;
            }
        } else if ((RNG <= 20 && RNG > 10) || prizeTokenId == 15) {
            if (lotteryPools[_poolId].winningTicketsRemaining[1] == 1) {
                prizeTokenId = 15;
                userWinningTickets[_user][lotteryPools.length - 1][1]++;
                lotteryPools[_poolId].winningTicketsRemaining[1]--;
            } else {
                prizeTokenId = 16;
            }
        } else if ((RNG <= 30 && RNG > 20) || prizeTokenId == 16) {
            if (lotteryPools[_poolId].winningTicketsRemaining[2] == 1) {
                prizeTokenId = 16;
                userWinningTickets[_user][lotteryPools.length - 1][2]++;
                lotteryPools[_poolId].winningTicketsRemaining[2]--;
            } else {
                prizeTokenId = 17;
            }
        } else if (RNG <= 60 && RNG > 30) {
            if (lotteryPools[_poolId].winningTicketsRemaining[3] > 0) {
                prizeTokenId = 17;
                userWinningTickets[_user][lotteryPools.length - 1][3]++;
                lotteryPools[_poolId].winningTicketsRemaining[3]--;
                lotteryPools[_poolId].totalPrizeTickets_4_5[0]++;
            } else {
                prizeTokenId = 18;
            }
        } else if (RNG > 60 || prizeTokenId == 18) {
            if (lotteryPools[_poolId].winningTicketsRemaining[3] > 0) {
                prizeTokenId = 18;
                userWinningTickets[_user][lotteryPools.length - 1][4]++;
                lotteryPools[_poolId].winningTicketsRemaining[4]--;
                lotteryPools[_poolId].totalPrizeTickets_4_5[1]++;
            } else {
                prizeTokenId = 17;
            }
        }
        lotteryPools[_poolId].unusedPrizeTickets--;
        ZDK.cosmicMutation(WINNING_TOKEN_ID, prizeTokenId, _user);
    }

    //CHAINLINK CALLBACK FUNCTION
    /**
     * @dev Callback function used by VRF Coordinator
     * @dev This function is called by the VRF Coordinator when a random result is ready to be consumed.
     * @param requestId The ID of the request sent to the VRF Coordinator
     * @param randomWords The random words sent by the VRF Coordinator
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        RequestVRF memory request = requests[requestId];
        if(request.fulfilled){
            revert RequestAlreadyFulfilled();
        }
        
        requests[requestId].fulfilled = true;

        if (request.isSpin) {
            spinTheWheel(request.zodiakChoice, randomWords[0], request.requester);
        } else {
            revealPrize(request.poolId, randomWords[0], request.requester);
        }
    }
}

/**
 * REMARKS***
 * - I recommand having odds values as variables and not hardcoding them, it will make the code more flexible and easier to maintain.
 * - WARNING: RevealPrize is working with randomness, maybe there will be no winner for a prize, the case should be handled (=> the unused money goes to ..., or esle ...?).
 */
