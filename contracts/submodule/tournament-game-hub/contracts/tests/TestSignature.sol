// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {Signature} from "../libraries/Signature.sol";

contract TestSignature {
    function verifyEthSignature(
        address _signer,
        bytes32 _data,
        bytes memory _signature
    ) external pure returns (bool) {
        return Signature.verifyEthSignature(_signer, _data, _signature);
    }
}