// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

library Set {
    struct AddressSet {
        address[] values;
        mapping(address => uint64) positions;
    }

    error SetValueNotFound(address value);
    error DuplicatedSetValue(address value);

    function insert(AddressSet storage _set, address _value) internal {
        if (_set.positions[_value] != 0) revert DuplicatedSetValue(_value);
        _set.values.push(_value);
        _set.positions[_value] = uint64(_set.values.length);
    }

    function erase(AddressSet storage _set, address _value) internal {
        uint64 p = _set.positions[_value];
        if (p == 0) revert SetValueNotFound(_value);
        unchecked {
            _set.values[p - 1] = _set.values[_set.values.length - 1];
            _set.positions[_set.values[p - 1]] = p;
        }
        _set.values.pop();
        _set.positions[_value] = 0;
    }

    function hasValue(AddressSet storage _set, address _value) internal view returns (bool) {
        return _set.positions[_value] != 0;
    }

    function isEmpty(AddressSet storage _set) internal view returns (bool) {
        return _set.values.length == 0;
    }

    function size(AddressSet storage _set) internal view returns (uint256) {
        return _set.values.length;
    }
}
