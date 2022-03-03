// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

interface IAutoBSW {
    function balanceOf() external view returns(uint);
    function totalShares() external view returns(uint);

    struct UserInfo {
        uint shares; // number of shares for a user
        uint lastDepositedTime; // keeps track of deposited time for potential penalty
        uint BswAtLastUserAction; // keeps track of Bsw deposited at the last user action
        uint lastUserActionTime; // keeps track of the last user action time
    }

    function userInfo(address user) external view returns (UserInfo memory);
}