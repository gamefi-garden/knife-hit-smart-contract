// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {ECDSAUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

library Signature {
    function verifyEthSignature(
        address _signer,
        bytes32 _data,
        bytes memory _signature
    ) internal pure returns (bool) {
        bytes32 ethSignedMessageHash = ECDSAUpgradeable.toEthSignedMessageHash(_data);
        (address signer, ) = ECDSAUpgradeable.tryRecover(ethSignedMessageHash, _signature);
        return signer == _signer;
    }
}
