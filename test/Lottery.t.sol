// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {ZodiakLottery} from "../src/ZodiakLottery.sol";
import {ZodiakNFT} from "../src/ZodiakNFT.sol";

contract LotteryTest is Test {
    ZodiakLottery public lottery;
    ZodiakNFT public nft;
    address public owner = vm.addr(1);
    address public player1 = vm.addr(2);

    function setUp() public {
        lottery = new ZodiakLottery(owner, owner, "https://zodiak333.casino");
        nft = ZodiakNFT(address(lottery.ZDK()));
    }

    function test_CreateTicket() public {

        vm.startPrank(player1);
        lottery.createTicket{value: 0.05 ether}(5);
        vm.stopPrank();

        uint balance = nft.balanceOf(player1, 0);
        assertEq(balance, 5);
    }

    // function test_Increment() public {
    //     counter.increment();
    //     assertEq(counter.number(), 1);
    // }

    // function testFuzz_SetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}
