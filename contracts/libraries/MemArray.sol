// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library MemArray {
    struct List {
        uint count;
        uint[] items;
    }

    function add(List memory self, uint item) pure internal{
        uint count = self.count;
        unchecked {
            if (count == self.items.length) {
                uint[] memory newItems = new uint[](self.items.length == 0 ? 4 : self.items.length << 1);
                for (uint i = 0; i < count; ++i) {
                    newItems[i] = self.items[i];
                }
                self.items = newItems;
            }
            self.items[count] = item;
            self.count++;
        }
    }
    function contains(List memory self, uint item) pure internal returns (bool){
        uint count = self.count;
        unchecked {
            for (uint i = 0; i < count; i++) {
                if (self.items[i] == item) {
                    return true;
                }
            }
            return false;
        }
    }
    function clear(List memory self) pure internal{
        self.count = 0;
    }
    function removeAtSwapback(List memory self, uint256 index)pure internal{
        unchecked{
            self.items[index] = self.items[--self.count];
        }
    }
    function ensureCapacity(List memory self, uint capacity) internal pure {
        unchecked{
            if (self.items.length < capacity){
                uint oldCount = self.count;
                uint[] memory newItems = new uint[](capacity);
                for (uint i = 0; i < oldCount; ++i) {
                    newItems[i] = self.items[i];
                }
                self.items = newItems;
            }
        }
    }

    // item number must be from 0 to 255
    struct MaskList {
        uint mask;
        uint8 count;
        uint8 expandCount;
        uint8[] items;
    }
    function setup(MaskList memory self, uint8 expandCount) pure internal{
        self.expandCount = expandCount;
    }
    function add(MaskList memory self, uint8 item) pure internal{
        unchecked {
            uint count = self.count;
            if (count == self.items.length) {
                uint8[] memory newItems = new uint8[](self.items.length + self.expandCount);
                for (uint i = 0; i < count; ++i) {
                    newItems[i] = self.items[i];
                }
                self.items = newItems;
            }
            self.items[self.count++] = item;
            self.mask |= 1 << item;
        }
    }
    function contains(MaskList memory self, uint8 item) pure internal returns (bool){
        return self.mask & 1 << item != 0;
    }
    function clear(MaskList memory self) pure internal{
        self.count = 0;
        self.mask = 0;
    }

    // up to 256 items
    struct Mask256{
        uint256 mask;
        uint[] items;
    }
    function setup(Mask256 memory self, uint count) pure internal{
        self.items = new uint[](count);
    }
    function setValueAt(Mask256 memory self, uint256 index, uint value)pure internal{
        self.items[index] = value;
        self.mask |= 1 << index;
    }
    function removeAt(Mask256 memory self, uint256 index)pure internal{
        self.mask &= ~(1 << index);
    }
    function containsAt(Mask256 memory self, uint256 index)pure internal returns (bool){
        return self.mask & 1 << index != 0;
    }

    function add(ListUint8_31 self, uint8 value) internal pure returns (ListUint8_31){
        unchecked{
            uint items = ListUint8_31.unwrap(self);
            uint count = uint8(items >> 248);
            items |= uint(value) << (count << 3);
            items ^= (count ^ (count + 1)) << 248;
            return ListUint8_31.wrap(items);
        }
    }
    // function set(ListUint8_31 self, uint index, uint8 value) internal pure returns (ListUint8_31){
    //     uint oldVal = ListUint8_31.unwrap(self) >> (index << 3);
    //     return ListUint8_31.wrap(ListUint8_31.unwrap(self) ^ ((oldVal ^ value) << (index << 3)));
    // }
    function get(ListUint8_31 self, uint index) internal pure returns (uint8){
        return uint8(ListUint8_31.unwrap(self) >> (index << 3));
    }
    function getCount(ListUint8_31 self) internal pure returns (uint){
        return uint8(ListUint8_31.unwrap(self) >> 248);
    }

    function set(SetUint8_32 memory self, uint index, uint8 value) internal pure{
        uint oldVal = self.items >> (index << 3);
        self.items ^= ((oldVal ^ value) << (index << 3));
    }
    function get(SetUint8_32 memory self, uint index) internal pure returns (uint8){
        return uint8(self.items >> (index << 3));
    }
    function clear(SetUint8_32 memory self) internal pure {
        self.items = 0;
    }
}

type ListUint8_31 is uint;
struct SetUint8_32{
    uint items;
}