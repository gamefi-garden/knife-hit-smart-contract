// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IAddressComparator} from "../interfaces/IAddressComparator.sol";

library Heap {
    struct AddressHeap {
        mapping(uint256 => address) values;
        mapping(address => uint256) positions;
        address comparator;
        uint32 size;
    }

    error EmptyHeap();
    error HeapValueNotFound(address value);
    error DuplicatedHeapValue(address value);

    function _up(AddressHeap storage _heap, uint256 _node, address _addr) private {
        mapping(uint256 => address) storage values = _heap.values;
        mapping(address => uint256) storage positions = _heap.positions;
        function(address, address) external view returns (bool) compare = IAddressComparator(_heap.comparator).compare;
        while (_node > 1) {
            uint256 parentNode = _node >> 1;
            address parentAddr = values[parentNode];
            if (compare(parentAddr, _addr)) break;
            values[parentNode] = _addr;
            positions[_addr] = parentNode;

            values[_node] = parentAddr;
            positions[parentAddr] = _node;

            _node = parentNode;
        }
    }

    function _down(AddressHeap storage _heap, uint256 _node, address _addr) private {
        mapping(uint256 => address) storage values = _heap.values;
        mapping(address => uint256) storage positions = _heap.positions;
        function(address, address) external view returns (bool) compare = IAddressComparator(_heap.comparator).compare;
        uint256 size = _heap.size;
        while (true) {
            uint256 childNode = _node << 1;
            address childAddr = values[childNode];
            if (childNode > size) break;
            if (childNode < size && compare(values[childNode | 1], childAddr)) {
                childNode |= 1;
                childAddr = values[childNode];
            }

            if (compare(_addr, childAddr)) break;
            values[childNode] = _addr;
            positions[_addr] = childNode;

            values[_node] = childAddr;
            positions[childAddr] = _node;

            _node = childNode;
        }
    }

    function up(AddressHeap storage _heap, address _addr) internal {
        uint256 node = _heap.positions[_addr];
        if (node == 0) revert HeapValueNotFound(_addr);
        _up(_heap, node, _addr);
    }

    function down(AddressHeap storage _heap, address _addr) internal {
        uint256 node = _heap.positions[_addr];
        if (node == 0) revert HeapValueNotFound(_addr);
        _down(_heap, node, _addr);
    }

    function hasValue(AddressHeap storage _heap, address _addr) internal view returns (bool) {
        return _heap.positions[_addr] != 0;
    }

    function push(AddressHeap storage _heap, address _addr) internal {
        if (_heap.positions[_addr] != 0) revert DuplicatedHeapValue(_addr);
        uint256 node = ++_heap.size;
        _heap.values[node] = _addr;
        _heap.positions[_addr] = node;
        _up(_heap, node, _addr);
    }

    function peek(AddressHeap storage _heap) internal view returns (address) {
        if (_heap.size == 0) revert EmptyHeap();
        return _heap.values[1];
    }

    function pop(AddressHeap storage _heap) internal {
        if (_heap.size == 0) revert EmptyHeap();
        if (_heap.size == 1) {
            _heap.size = 0;
            _heap.positions[_heap.values[1]] = 0;
        } else {
            mapping(uint256 => address) storage values = _heap.values;
            mapping(address => uint256) storage positions = _heap.positions;
            address addr = values[_heap.size];
            positions[values[1]] = 0;
            values[1] = addr;
            positions[addr] = 1;
            _heap.size--;
            _down(_heap, 1, addr);
        }
    }

    function remove(AddressHeap storage _heap, address _addr) internal {
        if (_heap.positions[_addr] == 0) revert HeapValueNotFound(_addr);

        mapping(address => uint256) storage positions = _heap.positions;
        uint256 node = positions[_addr];
        positions[_addr] = 0;
        if (node == _heap.size) {
            _heap.size--;
        } else {
            mapping(uint256 => address) storage values = _heap.values;
            address newAddr = values[_heap.size];
            _heap.size--;
            values[node] = newAddr;
            positions[newAddr] = node;
            if (node != 1 && IAddressComparator(_heap.comparator).compare(newAddr, values[node >> 1])) {
                _up(_heap, node, newAddr);
            } else {
                _down(_heap, node, newAddr);
            }
        }
    }
}
