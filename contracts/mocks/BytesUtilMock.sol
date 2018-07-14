pragma solidity 0.4.24;

import "../util/BytesUtil.sol";


contract BytesUtilMock {
    function sliceUint(bytes bs, uint start) public pure returns (uint) {
        return BytesUtil.sliceUint(bs, start);
    }

    function sliceUints(bytes bs, uint start, uint count) public pure returns (uint[]) {
        return BytesUtil.sliceUints(bs, start, count);
    }
}
