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

contract ZodiakLottery {
    ZodiakNFT public immutable ZDK;
    uint256 constant WHEEL_TICKET = 0;
    uint256 constant WINNING_TOKEN_ID = 13;

    constructor(address _theMighty) {
        ZDK = new ZodiakNFT("https://zodiaknft.com/", _theMighty);
    }

    /**
        * @dev Spin the wheel and see if you win or not; 12% chance of winning
        * @param _zodiakChoice the id of the zodiak to mutate to
        * @return win true if the user wins, false otherwise
     */
    function spinTheWheel(uint256 _zodiakChoice) public returns (bool win){
        require(ZDK.balanceOf(msg.sender, WHEEL_TICKET) >= 1, "Insufficient balance");
        require(_zodiakChoice > 0 &&_zodiakChoice < WINNING_TOKEN_ID , "Invalid id");

        //get a random number between 0 and 100
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, _zodiakChoice))) % 101;
        if(randomNumber < 12) {
            // mutate the token into winning ticket
            ZDK.cosmicMutation(WHEEL_TICKET, WINNING_TOKEN_ID , msg.sender);
            win = true;
        }
        else {
            // mutate the token into the zodiak booster
            ZDK.cosmicMutation(WHEEL_TICKET, _zodiakChoice , msg.sender);
            win = false;
        }  
    }

    // Once user has wining ticket, they can launch secondary spin to reveal their prize ticket, 1 off 5 prize tickets
    //natspec comment
    /**
        * @dev Reveal the prize ticket
        * @return prizeTokenId the id of the prize token
     */
    function revealPrize() public returns (uint256 prizeTokenId){
        require(ZDK.balanceOf(msg.sender, WINNING_TOKEN_ID) > 0, "Insufficient balance");

        //get a random number between 0 and 100
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, "Zodiak"))) % 100;
        
       if(randomNumber <= 20) {
            prizeTokenId = 14;
        }
        else if(randomNumber <= 40 && randomNumber > 20) {
            prizeTokenId = 15;
        }
        else if(randomNumber <= 60 && randomNumber > 40) {
            prizeTokenId = 16;
        }
        else if(randomNumber <= 80 && randomNumber > 60) {
            prizeTokenId = 17;
        }
        else if(randomNumber > 80) {
            prizeTokenId = 18;
        }
        ZDK.cosmicMutation(WINNING_TOKEN_ID, prizeTokenId, msg.sender);
    }

}