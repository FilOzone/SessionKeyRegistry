// SPDX-License-Identifier: Apache-2.0 OR MIT
pragma solidity^0.8.30;

import "forge-std/Script.sol";

import {SessionKeyRegistry} from "../src/SessionKeyRegistry.sol";

contract Profile is Script {
    function run() public {
        vm.startBroadcast();
        SessionKeyRegistry registry = new SessionKeyRegistry();
    }
}
