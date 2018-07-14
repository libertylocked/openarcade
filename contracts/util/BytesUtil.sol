/* solium-disable security/no-inline-assembly */
pragma solidity 0.4.24;


library BytesUtil {
    function sliceUint(bytes bs, uint start)
        internal pure
        returns (uint)
    {
        require(bs.length >= start + 32, "slicing out of range");
        uint x;
        assembly {
            x := mload(add(bs, add(0x20, start)))
        }
        return x;
    }

    function sliceUints(bytes bs, uint start, uint count)
        internal pure
        returns (uint[])
    {
        uint[] memory arr = new uint[](count);
        for (uint ai = 0; ai < count; ai++) {
            arr[ai] = sliceUint(bs, start + 32 * ai);
        }
        return arr;
    }
}
