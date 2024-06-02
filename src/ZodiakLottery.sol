// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// enum ZodiakSign {
//     WheelTicket(0)
//     Aries(1),
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
//     WinningUndisdistributed (13),
//     Prize1 (14),
//     Prize2 (15),
//     Prize3 (16),
//     Prize4 (17),
//     Prize5 (18),
// }

//WARNING: if the poolDuration is changed, the chainlink upkeep time will need to be updated

import {ZodiakNFT} from "./ZodiakNFT.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "./CosmicVault.sol";

error IncorrectAmount(uint256 amountSent, uint256 amountRequired);

error InvalidId(uint256 id);

error CannotTallyPool();

error NoWinningTickets();

error CannotSkimPool();

error CannotSpinTheWheel();

error InsufficientBalance();

error CannotCreateNewPool();

error RequestAlreadyFulfilled();

error ClaimPeriodEnded();

error TransferFailed();

error QueueIsEmpty();

contract ZodiakLottery is VRFConsumerBaseV2Plus {
    //ZodiakNFT contract
    ZodiakNFT public immutable ZDK;

    //The holder of money for easier accountability.
    CosmicVault public immutable COSMIC_VAULT;

    //The creator and administrator of the contract
    address public theMighty;

    //the id of the wheel ticket
    uint256 constant WHEEL_TICKET = 0;

    //the id of the winning undisdistributed token
    uint256 constant WINNING_TOKEN_ID = 13;

    uint256 ticketPrice = 0.01 ether;

    uint256 reserve;

    uint256 public allPoolDuration = 600;     // 8 * 1 hours; //hardcoded to be 8 hours

    uint256 public claimPeriodDuration = 600; // 24 * 1 hours; //hardcoded to be 24 hours

    // all the pools
    Pool[] public lotteryPools;

    uint256[] public playingQueue;

    uint256[] public claimingQueue;

    mapping(address _account => bool isOverseer) public isOverseer;

    // All requests sent to the VRF Coordinator and fulfilled
    mapping(uint256 requestId => RequestVRF request) public requests;

    //track the number of winning tickets per user per pool
    mapping(address user => mapping(uint256 pool => uint256 numOfWin)) public userWinningTicketsCount; //total number of prize tickets
    //CHECK: track user gains per pool ?

    //CHECK: use packing (starttimestamp + endtimestamp + numOfPlays + numOfWinners + unusedPrizeTickets) ?
    /**
     * @dev A pool is a period of time where users can buy tickets and win prizes
     * @param startTimestamp the start of the pool
     * @param endTimestamp the end of the pool
     * @param pot the total amount of money in the pool
     * @param remainingPot the amount of money left in the pool
     * @param numberOfWinningTickets the number of winning tickets in the pool
     * @param tierPot the pot for each prize tier
     * @param winningTicketsRemaining the number of winning tickets remaining for each prize tier
     * @param prizeAmount_4_5 the amount of prize 4 and 5 each prize ticket will get. calculated once the pool is tallied
     * @param unusedPrizeTickets the number of prize tickets that have not been claimed
     * @param tallied true if the pool has been tallied. Once tallied, lottery tickets can no longer be used and prizes can be claimed.
     * @param distributed true if the pool is distributed. Once closed, prizes can no longer be claimed. The remaining pot can be skimmed.
     */
    struct Pool {
        uint256 poolId;
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 numOfPlays;
        uint256 pot;
        uint256 remainingPot;
        uint256 numberOfWinningTickets;
        uint256[5] tierPot;
        uint256[5] winningTicketsRemaining;
        uint256[2] prizeAmount_4_5;
        uint256 unusedPrizeTickets;
        bool tallied;
        bool distributed;
    }

    /**
     * @dev A request to the VRF Coordinator
     * @param zodiakChoice the zodiak booster of choice in case of loss
     * @param poolId the id of the pool to reveal the prize ticket from
     * @param isSpin true if the request is to spin the wheel
     * @param fulfilled true if the request has been fulfilled
     * @param requester the address of the user who made the request
     */
    struct RequestVRF {
        uint256 zodiakChoice;
        uint256 poolId;
        bool isSpin;
        bool fulfilled;
        address requester;
    }

    //TODO: hardcoded now, replace for production
    //---------------------------------
    //    CHAINLINK VARIABLES
    //---------------------------------

    // The Chainlink VRF Coordinator contract
    IVRFCoordinatorV2Plus COORDINATOR;

    // The Chainlink VRF Coordinator address
    address immutable SEPOLIA_VRF_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;

    // The Chainlink VRF subscription ID for requesting randomness
    uint256 s_subscriptionId = 27067095552174340515575174004867124610273397868155706358653240940615672402888;

    // The Chainlink VRF key hash for requesting randomness
    bytes32 keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    // max allowed gas for the VRF callback
    uint32 callbackGasLimit = 1_000_000;

    // number of confirmations required for the VRF request
    uint16 requestConfirmations = 3;

    //---------------------------------
    //       EVENTS
    //---------------------------------

    // emit a {PoolTallied} event when a pool is tallied
    event PoolTallied(uint256 indexed poolId, uint256 pot, uint256 numOfWinners);

    // emit a {PrizeClaimed} event when a prize is claimed in a pool by a user and the prize is revealed & claimed
    event PrizeClaimed(uint256 indexed poolId, address indexed user, uint256 indexed prizeTokenId);

    // emit a {LotteryTicketCreated} event when a user creates a lottery ticket
    event LotteryTicketCreated(address indexed user, uint256 amount);

    // emit a {WheelSpinned} event when a user spins the wheel
    event WheelSpinned(uint256 indexed poolId, address indexed user, bool indexed win, uint256 zodiakChoice, uint256 _numOfWin, uint256 _numofPlayers);

    // emit a {RequestFulfilled} event when a VRF request is fulfilled
    event RequestFulfilled(uint256 indexed requestId, uint256[] randomWords);

    // emit a {PoolCreated} event when a new pool is created
    event PoolCreated(uint256 indexed poolId, uint256 duration);

    // Restriction for functions calls. theOverseer = automation contract, theMighty = EOA admin
    modifier cosmicAuthority() {
        require(isOverseer[msg.sender] || msg.sender == theMighty || msg.sender == address(this), "Only Cosmic powers can call this function");
        _;
    }

    constructor(address _theMighty, string memory _URI)
        VRFConsumerBaseV2Plus(SEPOLIA_VRF_COORDINATOR)
    {
        COSMIC_VAULT = new CosmicVault();
        COORDINATOR = IVRFCoordinatorV2Plus(SEPOLIA_VRF_COORDINATOR);
        lotteryPools.push(
            Pool(0 ,0, 0, 0, 0, 0, 0, [uint256(0), 0, 0, 0, 0], [uint256(0), 0, 0, 0, 0], [uint256(0), 0], 0, false, false)
        );
        ZDK = new ZodiakNFT(_URI, _theMighty);
        theMighty = _theMighty;
        
    }

    //=====================================================================================
    //
    //                     FUNCTIONS FOR TESTING AND BUILDING
    //
    //=====================================================================================

    function setOverseer(address _overseer) external cosmicAuthority {
        isOverseer[_overseer] = true;
    }

    function removeOverseer(address[] calldata _overseers) public {
        for(uint256 i = 0; i < _overseers.length; i++){
            isOverseer[_overseers[i]] = false;
        }
    }

    function setTheMighty(address _mighty) external cosmicAuthority {
        theMighty = _mighty;
    }

    function setTheCoordinator(address _coordinator) external cosmicAuthority {
        COORDINATOR = IVRFCoordinatorV2Plus(_coordinator);
    }

    function helperWinTickets(uint256 _poolId, uint256 _amount, address _to) external payable {
        if (msg.value < 0.01 ether * _amount) {
            revert IncorrectAmount(msg.value, 0.01 ether * _amount);
        }
        lotteryPools[_poolId].numberOfWinningTickets += _amount;
        lotteryPools[_poolId].unusedPrizeTickets += _amount;
        userWinningTicketsCount[_to][_poolId] += _amount;
        lotteryPools[_poolId].pot += msg.value;
        ZDK.createTicket(_amount, msg.sender);
    }


    function extendPoolDuration(uint256 _poolId, uint256 _time) external cosmicAuthority {
        lotteryPools[_poolId].endTimestamp += _time;
    }

    function timestamp() view public returns(uint256){
        return block.timestamp;
    }

    //=====================================================================================
    //
    //                     FUNCTIONS FOR THE LOTTERY
    //
    //=====================================================================================

    //----------------------------------------
    //            EXTERNAL FUNCTIONS
    //----------------------------------------
    /**
     * @dev Create a lottery ticket
     * @param _amount the amount of tickets to create
     */
    function createTicket(uint256 _amount) external payable {
        if (msg.value < 0.01 ether * _amount) {
            revert IncorrectAmount(msg.value, 0.01 ether * _amount);
        }
        reserve += msg.value;
        emit LotteryTicketCreated(msg.sender, _amount);
        ZDK.createTicket(_amount, msg.sender);
    }

    

    function modifyAllPoolDuration(uint256 _newDuration) external cosmicAuthority {
        allPoolDuration = _newDuration;
    }

    //WARNING: tally pool pops an element of playingQueue
    function upkeepTallyPool() public cosmicAuthority {
        if (playingQueue.length < 1) {
            revert QueueIsEmpty();
        }
        for(uint256 i = 0; i < playingQueue.length; i++) {
            uint256 poolId = playingQueue[i];
            if (lotteryPools[poolId].endTimestamp < block.timestamp && lotteryPools[poolId].numberOfWinningTickets >= 10) {
                tallyPool(poolId);
                i = i--;
            }
        }
    }

    function upkeepClosePool() public cosmicAuthority {
        if (claimingQueue.length < 1) {
            revert QueueIsEmpty();
        }
        for(uint256 i = 0; i < claimingQueue.length; i++) {
            if (lotteryPools[claimingQueue[i]].tallied && lotteryPools[claimingQueue[i]].endTimestamp + claimPeriodDuration < block.timestamp) {
                closePool(claimingQueue[i]);
                i = i--;
            }
        }
    }

    /**
     * @dev triggers VRF callback that will launch the spin of the wheel
     * @param _zodiakChoice the zodiak booster of choice in case of loss
     */
    function launchSpin(uint256 _zodiakChoice, uint256 _poolId) external {
        if (block.timestamp > lotteryPools[_poolId].endTimestamp) {
            revert CannotSpinTheWheel();
        }
        if (ZDK.balanceOf(msg.sender, WHEEL_TICKET) < 1) {
            revert InsufficientBalance();
        }
        if (_zodiakChoice < 1 || _zodiakChoice >= WINNING_TOKEN_ID) {
            revert InvalidId(_zodiakChoice);
        }

        uint256 requestID = requestRandomWords(1);

        requests[requestID].zodiakChoice = _zodiakChoice;
        requests[requestID].isSpin = true;
        requests[requestID].poolId = _poolId;
        requests[requestID].requester = msg.sender;
    }

    /**
     * @dev for winning ticket holders to reveal their prize ticket
     * @dev triggers VRF for RNG callback, that will start the reveal of the prize ticket
     * @param _poolId the id of the pool to reveal the prize ticket from
     */
    function launchReveal(uint256 _poolId) external {
        if (lotteryPools[_poolId].tallied && lotteryPools[_poolId].distributed) {
            revert ClaimPeriodEnded();
        }
        if (ZDK.balanceOf(msg.sender, WINNING_TOKEN_ID) < 1 && userWinningTicketsCount[msg.sender][_poolId] < 1) {
            revert InsufficientBalance();
        }

        uint256 requestID = requestRandomWords(1);

        requests[requestID].poolId = _poolId;
        requests[requestID].requester = msg.sender;
    }

    //----------------------------------------
    //            PUBLIC FUNCTIONS
    //----------------------------------------

    //TODO change hardcoded time to dynamic variable
    /**
     * @dev Create a new pool
     * @dev register to playing queues
     * @return the id of the new pool
     */
    function createPool() public cosmicAuthority returns (uint256) {
        Pool memory newPool;
        newPool.startTimestamp = block.timestamp;
        newPool.endTimestamp = block.timestamp + allPoolDuration; //hardcoded to be 20 minutes
        newPool.poolId = lotteryPools.length;
        lotteryPools.push(newPool);
        playingQueue.push(newPool.poolId);
        emit PoolCreated(lotteryPools.length - 1, allPoolDuration);
        return lotteryPools.length - 1;
    }

    //TODO: verify verify veryf test. Watch precision, float points, underflow/overflow ...
    /**
     * @dev tally the pool and do rewards accounting
     */
    function tallyPool(uint256 _poolId) public cosmicAuthority {
        Pool memory currentPoolM = lotteryPools[_poolId];
        Pool storage currentPoolS = lotteryPools[_poolId];

        if (currentPoolM.numberOfWinningTickets < 10) {
            revert NoWinningTickets();
        }
        // calculate and transfer fees for the house before distributing the pot
        uint256 fees = (currentPoolM.pot * 10) / 100;

        //calculate the number of tickets for prize 4 and 5
        // takes 30% and 70% of the winning tickets ( minus the 3 tickets for prize1,2,3) and add 3 in case prize 1,2,3 not won.
        uint256 numOfTickets_4 = ((currentPoolM.numberOfWinningTickets - 3) * 30) / 100 + 1;
        uint256 numOfTickets_5 = (currentPoolM.numberOfWinningTickets - 3) - numOfTickets_4 + 2;

        //take care of uneven distribution
        if (((currentPoolM.numberOfWinningTickets - 3) * 30) % 100 > 0) {
            numOfTickets_5++;
        }

        if (numOfTickets_4 == 0 || numOfTickets_5 == 0) {
            revert("Insufficient winning tickets to distribute prize 4 or 5.");
        }

        currentPoolS.pot = currentPoolM.pot = currentPoolM.pot - fees;
        currentPoolS.remainingPot = currentPoolM.pot;
        currentPoolS.tierPot[0] = (currentPoolM.pot * 25) / 100;
        currentPoolS.tierPot[1] = (currentPoolM.pot * 10) / 100;
        currentPoolS.tierPot[2] = (currentPoolM.pot * 5) / 100;
        currentPoolS.tierPot[3] = (currentPoolM.pot * 20) / 100;
        currentPoolS.tierPot[4] = (currentPoolM.pot * 40) / 100;
        currentPoolS.winningTicketsRemaining = [1, 1, 1, numOfTickets_4, numOfTickets_5];
        currentPoolS.prizeAmount_4_5 =
            [currentPoolS.tierPot[3] / numOfTickets_4, currentPoolS.tierPot[4] / numOfTickets_5];
        currentPoolS.unusedPrizeTickets = currentPoolM.numberOfWinningTickets;
        currentPoolS.tallied = true;

        claimingQueue.push(currentPoolS.poolId);

        //find and remove from playing queue
        for(uint256 i = 0; i < playingQueue.length; i++) {
            if (playingQueue[i] == _poolId) {
                playingQueue[i] = playingQueue[playingQueue.length - 1];
                playingQueue.pop();
            }
        }

        emit PoolTallied(lotteryPools.length - 1, currentPoolM.pot, currentPoolM.numberOfWinningTickets);

        (bool success,) = payable(address(COSMIC_VAULT)).call{value: fees}("");
        if (!success) {
            revert TransferFailed();
        }
    }

    function closePool(uint256 _poolId) public cosmicAuthority {
        lotteryPools[_poolId].distributed = true;
        
        //find pool and remove from claiming queue
        for (uint256 i = 0; i < claimingQueue.length; i++) {
            if (claimingQueue[i] == _poolId) {
                claimingQueue[i] = claimingQueue[claimingQueue.length - 1];
                claimingQueue.pop();
            }
        }

    }

    /**
     * @dev skim the funds of a fully redeemed pool
     */
    function skimPool(uint256 _poolId) public cosmicAuthority {
        if (!lotteryPools[_poolId].distributed) {
            revert CannotSkimPool();
        }
        //TODO: maybe instead of just transfering, it can be allocated (to a new pool? for other things?)
        payable(address(COSMIC_VAULT)).transfer(lotteryPools[_poolId].remainingPot);
    }

    /**
     * @dev Set the price of the wheel spinning ticket
     * @param _price the price of the NFT
     */
    function setPrice(uint256 _price) public {
        ticketPrice = _price;
    }

    function getPrizesPots(uint256 _poolId) public view returns (uint256[5] memory prizePots) {
        prizePots = lotteryPools[_poolId].tierPot;
    }

    function getRemainingWinTickets(uint256 _poolId) public view returns (uint256[5] memory remainingTickets) {
        remainingTickets = lotteryPools[_poolId].winningTicketsRemaining;
    }

    //---------------------------------------------
    //          INTERNAL FUNCTIONS
    //---------------------------------------------

    //Internal function called on VRF callback
    /**
     * @dev on VRF callback from fulfillRandomWords spins the wheel and mutate the token into the winning ticket or the zodiak booster of choice
     * @param _zodiakChoice the zodiak booster of choice
     * @param _randomWord the random number generated by the VRF
     * @param _owner the owner of the NFT
     * @return win true if the user wins, false if the user looses
     */
    function spinTheWheel(uint256 _zodiakChoice, uint256 _randomWord, address _owner, uint256 _poolId) internal returns (bool win) {
        //When the wheel is spinned, the price of a ticket is added to the pot
        //TODO: require enough lottery ticket
        Pool storage currentPool = lotteryPools[_poolId];
        currentPool.pot += 0.01 ether;

        //get a random number between 0 and 100
        uint256 RNG = _randomWord % 101;
        currentPool.numOfPlays++;
        //win or loose
        //CHECK for now 70% chance to win - only for development
        if (RNG < 70) {
            //make sure the number of winning tickets of a the current pool is accounted for
            currentPool.numberOfWinningTickets++;
            currentPool.unusedPrizeTickets++;
            userWinningTicketsCount[_owner][_poolId]++;
            win = true;

            // win: mutate the token into winning ticket
            ZDK.cosmicMutation(WHEEL_TICKET, WINNING_TOKEN_ID, _owner);
        } else {
            //lose: mutate the token into the zodiak booster of choice
            ZDK.cosmicMutation(WHEEL_TICKET, _zodiakChoice, _owner);
        }
        emit WheelSpinned(_poolId, _owner, win, _zodiakChoice, currentPool.numberOfWinningTickets, currentPool.numOfPlays);
    }

    //TODO: complex function, check all security and logic thoroughly
    //TODO: odds values should be variables
    //Internal function called on VRF callback
    /**
     * @dev on VRF callback reveals the prize ticket
     * @param _poolId the id of the pool to reveal the prize ticket from
     * @param _randomWord the random number generated by the VRF
     * @return prizeTokenId the id of the prize token
     */
    function revealAndClaimPrize(uint256 _poolId, uint256 _randomWord, address _user)
        internal
        returns (uint256 prizeTokenId)
    {
        //get a random number between 0 and 100
        uint256 RNG = _randomWord % 101;
        Pool memory currentPool = lotteryPools[_poolId];

        userWinningTicketsCount[_user][_poolId]--;

        if (RNG <= 10) {
            if (currentPool.winningTicketsRemaining[0] == 1) {
                prizeTokenId = 14;

                modifyPoolOnClaim(_poolId, 0, currentPool.tierPot[0], _user, prizeTokenId);

                return prizeTokenId;
            } else {
                prizeTokenId = 15;
            }
        } else if ((RNG <= 20 && RNG > 10) || prizeTokenId == 15) {
            if (currentPool.winningTicketsRemaining[1] == 1) {
                prizeTokenId = 15;

                modifyPoolOnClaim(_poolId, 1, currentPool.tierPot[1], _user, prizeTokenId);

                return prizeTokenId;
            } else {
                prizeTokenId = 16;
            }
        } else if ((RNG <= 30 && RNG > 20) || prizeTokenId == 16) {
            if (currentPool.winningTicketsRemaining[2] == 1) {
                prizeTokenId = 16;

                modifyPoolOnClaim(_poolId, 2, currentPool.tierPot[2], _user, prizeTokenId);

                return prizeTokenId;
            } else {
                prizeTokenId = 17;
            }
        } else if (RNG <= 60 && RNG > 30) {
            if (currentPool.winningTicketsRemaining[3] > 0) {
                prizeTokenId = 17;

                modifyPoolOnClaim(_poolId, 3, currentPool.tierPot[3], _user, prizeTokenId);

                return prizeTokenId;
            } else {
                prizeTokenId = 18;
            }
        } else if (RNG > 60 || prizeTokenId == 18) {
            if (currentPool.winningTicketsRemaining[4] > 0) {
                prizeTokenId = 18;

                modifyPoolOnClaim(_poolId, 4, currentPool.prizeAmount_4_5[1], _user, prizeTokenId);

                return prizeTokenId;
            } else {
                prizeTokenId = 17;
            }
        }
    }

    function modifyPoolOnClaim(uint256 _poolId, uint256 _prizeId, uint256 _value, address _user, uint256 _prizeTokenId)
        internal
    {
        lotteryPools[_poolId].winningTicketsRemaining[_prizeId]--;
        lotteryPools[_poolId].unusedPrizeTickets--;
        lotteryPools[_poolId].remainingPot -= _value;
        emit PrizeClaimed(_poolId, _user, _prizeTokenId);
        ZDK.cosmicMutation(WINNING_TOKEN_ID, _prizeTokenId, _user);
        (bool success,) = payable(_user).call{value: _value}("");
        if (!success) {
            revert TransferFailed();
        }
    }

    //CHAINLINK CALLBACK FUNCTION
    /**
     * @dev Callback function used by VRF Coordinator
     * @dev This function is called by the VRF Coordinator when a random result is ready to be consumed.
     * @param requestId The ID of the request sent to the VRF Coordinator
     * @param randomWords The random words sent by the VRF Coordinator
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        RequestVRF memory request = requests[requestId];
        if (request.fulfilled) {
            revert RequestAlreadyFulfilled();
        }

        requests[requestId].fulfilled = true;
        emit RequestFulfilled(requestId, randomWords);

        if (request.isSpin) {
            spinTheWheel(request.zodiakChoice, randomWords[0], request.requester, request.poolId);
        } else {
            revealAndClaimPrize(request.poolId, randomWords[0], request.requester);
        }
    }

    //----------------------------------------
    //            PRIVATE FUNCTIONS
    //----------------------------------------

    /**
     * @dev Request randomness
     * @return requestId The ID of the request sent to the VRF Coordinator
     */
    function requestRandomWords(uint32 _numOfWords) private returns (uint256 requestId) {
        // Will revert if subscription is not set and funded.
        // To enable payment in native tokens, set nativePayment to true.
        requestId = COORDINATOR.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: _numOfWords,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false})) //paying in LINK
            })
        );
    }
}

/**
 * REMARKS***
 * - I recommand having odds values as variables and not hardcoding them, it will make the code more flexible and easier to maintain.
 */
