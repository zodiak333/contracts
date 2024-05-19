// SPDX-License-Identifier: MIT 

pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "../src/ZodiakLottery.sol";

contract DeployLottery  is Script{
    address owner;

    function run() external returns (ZodiakLottery) {
        vm.startBroadcast();

        ZodiakLottery lottery = new ZodiakLottery(,,"");
        vm.stopBroadcast();
        return lottery;
    }
}