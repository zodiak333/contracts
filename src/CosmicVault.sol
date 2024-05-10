// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

contract CosmicVault {
    uint vaulting;
    receive() external payable { 
        vaulting += msg.value;
    }

    fallback() external payable {
        vaulting += msg.value;
    }
}