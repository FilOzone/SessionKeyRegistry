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
    mapping (
        address user => mapping (
            uint256 nonce => uint256
        )
    ) public signatureNonces;

    function _setAuthorizations(mapping (bytes32 => uint256) storage permissionExpiry, uint256 expiry, bytes32[] calldata permissions) internal {
        for (uint256 i = 0; i < permissions.length; i++) {
            permissionExpiry[permissions[i]] = expiry;
        }
    }

    /**
     * @notice Caller revokes from the signer the specified permissions
     * @param signer the authorized account
     * @param permissions the scope of authority to revoke from the signer
     */
    function revoke(address signer, bytes32[] calldata permissions) external {
        _setAuthorizations(authorizationExpiry[msg.sender][signer], 0, permissions);
    }

    /**
     * @notice Caller authorizes the signer with permissions until expiry
     * @param signer the account authorized
     * @param expiry when the authorization ends
     * @param permissions the scope of authority granted to the signer
     */
    function login(address signer, uint256 expiry, bytes32[] calldata permissions) external {
        _setAuthorizations(authorizationExpiry[msg.sender][signer], expiry, permissions);
    }

    /**
     * @notice Caller funds and authorizes the signer with permissions until expiry
     * @param signer the account authorized
     * @param expiry when the authorization ends
     * @param permissions the scope of authority granted to the signer
     */
    function loginAndFund(address payable signer, uint256 expiry, bytes32[] calldata permissions) external payable {
        _setAuthorizations(authorizationExpiry[msg.sender][signer], expiry, permissions);
        signer.transfer(msg.value);
    }

    struct Authorization {
        uint256 nonce;
        address signer;
        uint256 expiry;
        bytes32[] permissions;
    }

    struct SignedAuthorization {
        Authorization auth;
        // NOTE no v; just use malleable signatures; see EIP-2
        bytes32 r;
        bytes32 s;
    }

    function authorizationHash(Authorization calldata auth) public pure returns (bytes32 hash) {
        bytes32[] calldata permissions = auth.permissions;
        assembly ("memory-safe") {
            let fmp := mload(0x40)
            let permissionsLoc := permissions.offset
            let size := shl(5, permissions.length)
            calldatacopy(fmp, add(32, permissionsLoc), size)
            mstore(add(96, fmp), keccak256(fmp, size))
            calldatacopy(fmp, auth, 96)
            hash := keccak256(fmp, 128)
        }
    }

    function recoverSigner(SignedAuthorization calldata signed) public pure returns (address signer) {
        // TODO EIP-712 domainSeparator
        // NOTE if your v is 28, convert to 27 by flipping s = (secp256k1n - s)
        return ecrecover(authorizationHash(signed.auth), 27, signed.r, signed.s);
    }

    function loginFor(SignedAuthorization calldata signed) external payable {
        address user = recoverSigner(signed);
        require(user != address(0)); // ecrecover returns 0 on error
        signatureNonces[user][signed.auth.nonce] += uint256(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff); // this overflows if nonce already used
        _setAuthorizations(authorizationExpiry[user][signed.auth.signer], signed.auth.expiry, signed.auth.permissions);
    }
}
