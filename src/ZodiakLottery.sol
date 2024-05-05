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

contract ZodiakLottery is ZodiakNFT {
    ZodiakNFT public immutable ZDK;
    uint256 constant WHEEL_TICKET = 0;
    uint256 constant WINNING_TOKEN_ID = 13;
    address immutable COSMIC_VAULT;

    //CHECK: maybe can use packing
    struct Pool {
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 pot;
        uint256 remainingPot;
        uint256 numberOfWinningTickets;
        uint256 tier1;
        uint256 tier2;
        uint256 tier3;
        uint256 tier4;
        uint256 tier5;
        uint256[5] winningTicketsRemaining; // 0 = 1st prize, 1 = 2nd prize, 2 = 3rd prize, 3 = 4th prize, 4 = 5th prize
        uint256 unusedPrizeTickets;
    }

    mapping(address user => mapping(uint256 poolId => uint256[5])) public userWinningTickets; // 0 = 1st prize, 1 = 2nd prize, 2 = 3rd prize, 3 = 4th prize, 4 = 5th prize

    Pool[] public lotteryPools;

    constructor(address _theMighty, address _cosmicVault) ZodiakNFT("https://zodiaknft.com/", _theMighty) {
        COSMIC_VAULT = _cosmicVault;
    }

    function createPool() public cosmicAuthority {
        require(block.timestamp > lotteryPools[lotteryPools.length - 1].endTimestamp, "Cannot create new pool yet");
        Pool memory newPool;
        newPool.startTimestamp = block.timestamp;
        newPool.endTimestamp = block.timestamp + 3 hours;
        lotteryPools.push(newPool);
    }

    //WARNING: with rounding, each ticket might not be accounted for, add a check for that in favor of last prize.
    //Also needs to take into account that maybe no one will win 3 first prizes
    function tallyPool() public cosmicAuthority {
        Pool memory currentPoolM = lotteryPools[lotteryPools.length - 1];
        Pool storage currentPoolS = lotteryPools[lotteryPools.length - 1];

        // calculate and transfer fees for the house before distributing the pot
        uint256 fees = currentPoolM.pot * 10 / 100;

        currentPoolS.pot = currentPoolM.pot = currentPoolM.pot - fees;

        require(block.timestamp > currentPoolM.endTimestamp, "Cannot tally pool yet");
        require(currentPoolM.numberOfWinningTickets > 0, "No winning tickets");
        currentPoolS.tier1 = currentPoolM.pot * 25 / 100;
        currentPoolS.tier2 = currentPoolM.pot * 10 / 100;
        currentPoolS.tier3 = currentPoolM.pot * 5 / 100;
        currentPoolS.tier4 = currentPoolM.pot * 20 / 100;
        currentPoolS.tier5 = currentPoolM.pot * 40 / 100;
        currentPoolS.winningTicketsRemaining = [
            1,
            1,
            1,
            (currentPoolM.numberOfWinningTickets - 2) * 30 / 100,
            (currentPoolM.numberOfWinningTickets - 1) * 70 / 100
        ];
        //WARNING: for now add 3 more tickets to prize 4 & 5 to handle case no winners of first 3 prizes
        payable(COSMIC_VAULT).transfer(fees);
    }

    /**
     * @dev Spin the wheel and see if you win or not; 12% chance of winning
     * @param _zodiakChoice the id of the zodiak to mutate to
     * @return win true if the user wins, false otherwise
     */
    function spinTheWheel(uint256 _zodiakChoice) public returns (bool win) {
        require(block.timestamp < lotteryPools[lotteryPools.length - 1].endTimestamp, "Cannot spin the wheel yet");
        require(balanceOf(msg.sender, WHEEL_TICKET) >= 1, "Insufficient balance");
        require(_zodiakChoice > 0 && _zodiakChoice < WINNING_TOKEN_ID, "Invalid id");

        ////When the wheel is spinned, the price of a ticket is added to the pot
        lotteryPools[lotteryPools.length - 1].pot += 0.01 ether;

        //get a random number between 0 and 100
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, _zodiakChoice))) % 101;

        //win or loose
        if (randomNumber < 12) {
            //make sure the number of winning tickets of a the current pool is accounted for
            lotteryPools[lotteryPools.length - 1].numberOfWinningTickets++;
            lotteryPools[lotteryPools.length - 1].unusedPrizeTickets++;
            win = true;

            // win: mutate the token into winning ticket
            cosmicMutation(WHEEL_TICKET, WINNING_TOKEN_ID, msg.sender);
        } else {
            win = false;
            //lose: mutate the token into the zodiak booster of choice
            cosmicMutation(WHEEL_TICKET, _zodiakChoice, msg.sender);
        }
    }

    //TODO: cache lotteryPools[_poolId] for lot of gas savings
    //TODO: complex function, check all security and logic thoroughly
    //TODO: odds values should be variables

    // Once user has wining ticket, they can launch secondary spin to reveal their prize ticket, 1 off 5 prize tickets
    //natspec comment
    /**
     * @dev Reveal the prize ticket
     * @return prizeTokenId the id of the prize token
     */
    function revealPrize(uint256 _poolId) public returns (uint256 prizeTokenId) {
        require(balanceOf(msg.sender, WINNING_TOKEN_ID) > 0, "Insufficient balance");

        //get a random number between 0 and 100
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, "Zodiak"))) % 100;

        if (randomNumber <= 10) {
            if (lotteryPools[_poolId].winningTicketsRemaining[0] == 1) {
                prizeTokenId = 14;
                userWinningTickets[msg.sender][lotteryPools.length - 1][0]++;
                lotteryPools[_poolId].winningTicketsRemaining[0]--;
            } else {
                prizeTokenId = 15;
            }
        } else if (randomNumber <= 20 && randomNumber > 10 || prizeTokenId == 15) {
            if (lotteryPools[_poolId].winningTicketsRemaining[1] == 1) {
                prizeTokenId = 15;
                userWinningTickets[msg.sender][lotteryPools.length - 1][1]++;
                lotteryPools[_poolId].winningTicketsRemaining[1]--;
            } else {
                prizeTokenId = 16;
            }
        } else if (randomNumber <= 30 && randomNumber > 20 || prizeTokenId == 16) {
            if (lotteryPools[_poolId].winningTicketsRemaining[2] == 1) {
                prizeTokenId = 16;
                userWinningTickets[msg.sender][lotteryPools.length - 1][2]++;
                lotteryPools[_poolId].winningTicketsRemaining[2]--;
            } else {
                prizeTokenId = 17;
            }
        } else if (randomNumber <= 60 && randomNumber > 30) {
            if (lotteryPools[_poolId].winningTicketsRemaining[3] > 0) {
                prizeTokenId = 17;
                userWinningTickets[msg.sender][lotteryPools.length - 1][3]++;
                lotteryPools[_poolId].winningTicketsRemaining[3]--;
            } else {
                prizeTokenId = 18;
            }
        } else if (randomNumber > 60 || prizeTokenId == 18) {
            if (lotteryPools[_poolId].winningTicketsRemaining[3] > 0) {
            prizeTokenId = 18;
            userWinningTickets[msg.sender][lotteryPools.length - 1][4]++;
            lotteryPools[_poolId].winningTicketsRemaining[4]--;
            } else {
                prizeTokenId = 17;
            }
        }
        lotteryPools[_poolId].unusedPrizeTickets--;
        cosmicMutation(WINNING_TOKEN_ID, prizeTokenId, msg.sender);
    }

    //Skim the funds of a fully redeemed pool
    function skimPool(uint _poolId) public cosmicAuthority() {
        require(block.timestamp > lotteryPools[_poolId].endTimestamp, "Cannot skim pool yet");
        require(lotteryPools[_poolId].unusedPrizeTickets == 0, "Pool not fully redeemed");
        //TODO: maybe instead of just transfering, it can be allocated (to a new pool? for other things?)
        payable(COSMIC_VAULT).transfer(lotteryPools[_poolId].remainingPot);
    }
}

/**
 * REMARKS***
 * - I recommand having odds values as variables and not hardcoding them, it will make the code more flexible and easier to maintain.
 * - WARNING: RevealPrize is working with randomness, maybe there will be no winner for a prize, the case should be handled (=> the unused money goes to ..., or esle ...?).
 */
