// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IAddressComparator {
    function compare(address, address) external view returns (bool);
}
