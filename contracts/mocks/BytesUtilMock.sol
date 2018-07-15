pragma solidity 0.4.24;

import "../util/BytesUtil.sol";


contract BytesUtilMock {
    function slice(bytes bs, uint start, uint length) public pure returns (bytes) {
        return BytesUtil.slice(bs, start, length);
    }

    function sliceUint(bytes bs, uint start) public pure returns (uint) {
        return BytesUtil.sliceUint(bs, start);
    }

    function sliceUintArray(bytes bs, uint start, uint count) public pure returns (uint[]) {
        return BytesUtil.sliceUintArray(bs, start, count);
    }

    function toUintArray(bytes bs) public pure returns (uint[]) {
        return BytesUtil.toUintArray(bs);
    }
}
