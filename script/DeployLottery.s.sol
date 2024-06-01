// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "../src/ZodiakLottery.sol";

contract DeployLottery is Script {
    address owner = 0x107100756599668Ee64e3D2e5B7ae6454B247Ab7;
    address automation = vm.addr(2);
    address vrf = vm.addr(3);

    function run() external returns (ZodiakLottery) {
        vm.startBroadcast();

        ZodiakLottery lottery = new ZodiakLottery(owner, "");
        vm.stopBroadcast();
        return lottery;
    }
}
