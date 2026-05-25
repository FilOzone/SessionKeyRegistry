// SPDX-License-Identifier: Apache-2.0 OR MIT
pragma solidity ^0.8.30;

import {Errors} from "./Errors.sol";

contract SessionKeyRegistry {
    uint256 public constant MAX_EXPIRY = 30 days;
    uint256 public constant MIN_EXPIRY = 5 hours;
    uint256 public constant SLOT_DEPOSIT = 10 ether; // Deposit per permission slot

    struct PermissionData {
        uint64 expiry; // Timestamp when permission expires (sufficient until year 2554)
        uint192 deposit; // Deposit amount (max ~6.27e39 wei, way more than needed)
    }

    // Single mapping storing both expiry and deposit
    mapping(address user => mapping(address signer => mapping(bytes32 permission => PermissionData))) public
        authorizationExpiry;

    mapping(address user => uint256) public refundAmount;

    event AuthorizationsUpdated(
        address indexed identity, address signer, uint256 expiry, bytes32[] permissions, string origin
    );

    event DepositAdded(address indexed identity, uint256 amount);

    event DepositRefunded(address indexed identity, address indexed recipient, uint256 amount);

    function _setAuthorizations(
        address MsgSender,
        address signer,
        uint256 expiry,
        bytes32[] calldata permissions,
        string calldata origin
    ) internal {
        require(msg.sender == MsgSender || expiry == 0, Errors.PermissionNotExpired());
        require(
            expiry >= block.timestamp + MIN_EXPIRY && expiry <= block.timestamp + MAX_EXPIRY,
            Errors.ExpiryOutOfBounds()
        );
        mapping(bytes32 => PermissionData) storage permissionData = authorizationExpiry[MsgSender][signer];

        uint256 refund = 0;

        for (uint256 i = 0; i < permissions.length; i++) {
            bytes32 permission = permissions[i];
            PermissionData storage data = permissionData[permission];

            if (expiry > 0) {
                require(data.expiry < expiry, Errors.PermissionNotExpired());
                permissionData[permission] = PermissionData(uint64(expiry), uint192(SLOT_DEPOSIT));
                emit DepositAdded(MsgSender, SLOT_DEPOSIT);
            } else if (expiry == 0) {
                require(data.expiry != 0, Errors.PermissionNotSet());
                require(msg.sender == MsgSender || block.timestamp >= data.expiry, Errors.PermissionNotExpired());
                uint256 depositToRefund = data.deposit;
                if (depositToRefund > 0) {
                    refund += depositToRefund;
                }
                delete permissionData[permission];
            }
        }

        if (refund > 0) {
            refundAmount[MsgSender] += refund;
        }

        emit AuthorizationsUpdated(MsgSender, signer, expiry, permissions, origin);
    }

    /**
     * @notice Caller revokes from the signer the specified permissions
     * @param signer the authorized account
     * @param permissions the scope of authority to revoke from the signer
     * @param origin indicates what app prompted this revocation
     */
    function revoke(address signer, bytes32[] calldata permissions, string calldata origin) external {
        _setAuthorizations(msg.sender, signer, 0, permissions, origin);
    }

    /**
     * @notice Caller authorizes the signer with permissions until expiry
     * @param signer the account authorized
     * @param expiry when the authorization ends
     * @param permissions the scope of authority granted to the signer
     * @param origin indicates what app prompted this authorization
     */
    function login(address signer, uint256 expiry, bytes32[] calldata permissions, string calldata origin)
        external
        payable
    {
        uint256 requiredDeposit = permissions.length * SLOT_DEPOSIT;
        require(msg.value >= requiredDeposit, Errors.InsufficientDeposit(msg.value, requiredDeposit));
        _setAuthorizations(msg.sender, signer, expiry, permissions, origin);
    }

    /**
     * @notice Caller funds and authorizes the signer with permissions until expiry
     * @param signer the account authorized
     * @param expiry when the authorization ends
     * @param permissions the scope of authority granted to the signer
     * @param origin indicates what app prompted this authorization
     */
    function loginAndFund(
        address payable signer,
        uint256 expiry,
        bytes32[] calldata permissions,
        string calldata origin
    ) external payable {
        uint256 requiredDeposit = permissions.length * SLOT_DEPOSIT;
        require(msg.value > requiredDeposit, Errors.InsufficientDeposit(msg.value, requiredDeposit));
        _setAuthorizations(msg.sender, signer, expiry, permissions, origin);
        signer.transfer(msg.value - requiredDeposit);
    }

    /**
     * @notice Clears expired permissions and refunds deposits to caller
     * @param user the user whose permissions are being cleared
     * @param signer the signer whose permissions are being cleared
     * @param permissions the permissions to clear (must be expired)
     * @param origin indicates what app prompted this clearing
     */
    function clearExpired(address user, address signer, bytes32[] calldata permissions, string calldata origin)
        external
    {
        _setAuthorizations(user, signer, 0, permissions, origin);
    }

    /**
     * @notice Withdraws the caller's refundable deposit amount to the specified recipient
     * @param recipient the address to receive the refunded deposit
     */
    function withdrawRefund(address payable recipient) external {
        uint256 amount = refundAmount[msg.sender];
        require(amount > 0, Errors.InsufficientBalance());
        refundAmount[msg.sender] = 0;
        emit DepositRefunded(msg.sender, recipient, amount);
        (bool success,) = recipient.call{value: amount}("");
        require(success, Errors.TransferFailed());       
    }
}
