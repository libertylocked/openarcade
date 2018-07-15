/* solium-disable security/no-inline-assembly */
pragma solidity ^0.4.24;


library BytesUtil {
    /**
     * @dev Copies of a portion of a byte array into a new byte array
     * @param bs Original byte array
     * @param start Start index in the original array to slice from
     * @param length Number of bytes to copy
     * @return A new byte array copied from a portion of from original array
     */
    function slice(bytes bs, uint start, uint length)
        internal pure
        returns (bytes)
    {
        require(bs.length >= start + length, "slicing out of range");
        if (length == 0) {
            return new bytes(0);
        }
        uint wordCount = 1 + (length - 1) / 32;
        uint wi = 0;
        bytes memory sliced = new bytes(length);
        for (wi = 0; wi < wordCount; wi++) {
            assembly {
                let word := mload(add(bs, add(add(0x20, start), mul(wi, 0x20))))
                mstore(add(sliced, add(0x20, mul(wi, 0x20))), word)
            }
        }
        return sliced;
    }

    /**
     * @dev Gets an uint from a byte array
     * @param bs Original byte array
     * @param start Start index in the original array to copy a uint from
     * @return An uint copied from the byte array
     */
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

    /**
     * @dev Gets an uint array from a byte array
     * @param bs Original byte array
     * @param start Start index in the original array to copy uints from
     * @param count The number of uints to copy
     * @return An uint array copied from the byte array
     */
    function sliceUintArray(bytes bs, uint start, uint count)
        internal pure
        returns (uint[])
    {
        uint[] memory arr = new uint[](count);
        for (uint ai = 0; ai < count; ai++) {
            arr[ai] = sliceUint(bs, start + 32 * ai);
        }
        return arr;
    }

    /**
     * @dev Gets a uint array from the data in a byte array
     * @param bs Original byte array
     * @return A copied uint array
     */
    function toUintArray(bytes bs)
        internal pure
        returns (uint[])
    {
        require(bs.length % 32 == 0, "buffer size must be multiple of 32");
        return sliceUintArray(bs, 0, bs.length / 32);
    }
}
