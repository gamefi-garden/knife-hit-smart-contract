// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IAlphaKeysFactory {
    function getKeysPlayer(address _token) external view returns (address);
}
