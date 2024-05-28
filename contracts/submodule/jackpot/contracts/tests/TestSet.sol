// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IAddressComparator} from "../interfaces/IAddressComparator.sol";

import {Set} from "../libraries/Set.sol";

contract TestSet {
    using Set for Set.AddressSet;
    Set.AddressSet private set;

    function insert(address _addr) external {
        set.insert(_addr);
    }

    function erase(address _addr) external {
        set.erase(_addr);
    }

    function hasValue(address _addr) external view returns (bool) {
        return set.hasValue(_addr);
    }

    function isEmpty() external view returns (bool) {
        return set.isEmpty();
    }

    function size() external view returns (uint256) {
        return set.size();
    }

    function allValues() external view returns (address[] memory) {
        return set.values;
    }

    function allPositions() external view returns (uint256[] memory) {
        uint256 n = set.size();
        uint256[] memory positions = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) {
            positions[i] = set.positions[set.values[i]];
        }
        return positions;
    }

}
