// SPDX-License-Identifier: Apache-2.0 OR MIT
pragma solidity^0.8.30;

contract SessionKeyRegistry {
    mapping (
        address user => mapping (
            address signer => mapping (
                bytes32 permission => uint256
            )
        )
    ) public authorizationExpiry;

    function _setAuthorizations(address signer, uint256 expiry, bytes32[] calldata permissions) internal {
        mapping (bytes32 => uint256) storage permissionExpiry = authorizationExpiry[msg.sender][signer];
        for (uint256 i = 0; i < permissions.length; i++) {
            permissionExpiry[permissions[i]] = expiry;
        }
    }

    function revoke(address signer, bytes32[] calldata permissions) external {
        _setAuthorizations(signer, 0, permissions);
    }

    function login(address signer, uint256 expiry, bytes32[] calldata permissions) external {
        _setAuthorizations(signer, expiry, permissions);
    }

    function loginAndFund(address payable signer, uint256 expiry, bytes32[] calldata permissions) external payable {
        _setAuthorizations(signer, expiry, permissions);
        signer.transfer(msg.value);
    }
}
