// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IAlphaKeysFactory} from "../interfaces/IAlphaKeysFactory.sol";

contract TestAlphaKeysFactory is IAlphaKeysFactory, Initializable {
    mapping(address => address) public keys;

    // solhint-disable-next-line no-empty-blocks
    function initialize() external initializer {}

    function registerKeys(address _token) external {
        keys[_token] = msg.sender;
    }

    function getKeysPlayer(address _token) external view returns (address) {
        return keys[_token];
    }
}
