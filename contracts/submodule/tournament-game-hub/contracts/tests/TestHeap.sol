// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IAddressComparator} from "../interfaces/IAddressComparator.sol";

import {Heap} from "../libraries/Heap.sol";

contract TestHeap is Initializable, IAddressComparator {
    using Heap for Heap.AddressHeap;

    mapping(address => uint256) public values;
    Heap.AddressHeap private heap;

    function initialize() external initializer {
         heap.comparator = address(this);
    }

    function compare(address _addr1, address _addr2) external view returns (bool) {
        return values[_addr1] > values[_addr2];
    }

    function setValue(address _addr, uint256 _value) external {
        values[_addr] = _value;
    }

    function up(address _addr) external {
        heap.up(_addr);
    }

    function down(address _addr) external {
        heap.down(_addr);
    }

    function push(address _addr) external {
        heap.push(_addr);
    }

    function remove(address _addr) external {
        heap.remove(_addr);
    }

    function pop() external {
        heap.pop();
    }

    function size() external view returns (uint256) {
        return heap.size;
    }

    function allValues() external view returns (address[] memory) {
        uint256 n = heap.size;
        address[] memory addresses = new address[](n);
        for (uint256 i = 0; i < n; ++i) addresses[i] = heap.values[i+1];
        return addresses;
    }

    function allPositions() external view returns (uint256[] memory) {
        uint256 n = heap.size;
        uint256[] memory positions = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) {
            positions[i] = heap.positions[heap.values[i+1]];
        }
        return positions;
    }

    function hasValue(address _addr) external view returns (bool) {
        return heap.hasValue(_addr);
    }

    function peek() external view returns (address) {
        return heap.peek();
    }
}