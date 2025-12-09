// SPDX-License-Identifier: Apache-2.0 OR MIT
pragma solidity ^0.8.30;

library Errors {
    ///@notice Indicates that the provided deposit is insufficient
    ///@param provided the amount of deposit provided
    ///@param required the minimum required deposit amount
    error InsufficientDeposit(uint256 provided, uint256 required);

    ///@notice Indicates that a transfer of funds has failed
    error TransferFailed();

    ///@notice Indicates that the permission is not yet expired
    error PermissionNotExpired();

    ///@notice Indicates insufficient balance for refund
    error InsufficientBalance();

    ///@notice Indicates that the provided expiry is out of bounds
    error ExpiryOutOfBounds();

    ///@notice Indicates that the permission is not set
    error PermissionNotSet();
}
