pragma solidity 0.4.24;


library PlatformLib {
    function serializePoint2D(uint x, uint y)
        public pure
        returns (bytes)
    {
        return abi.encode(x, y);
    }

    function deserializePoint2D(bytes s)
        public pure
        returns (uint, uint)
    {
        require(s.length == 64);
        uint x = 0;
        uint y = 0;
        for (uint i = 0; i < 32; i++) {
            x = x | uint(s[31-i]) << i * 8;
            y = y | uint(s[63-i]) << i * 8;
        }
        return (x, y);
    }

    function serializePoint3D(uint x, uint y, uint z)
        public pure
        returns (bytes)
    {
        return abi.encode(x, y, z);
    }

    function deserializePoint3D(bytes s)
        public pure
        returns (uint, uint, uint)
    {
        require(s.length == 96);
        uint x = 0;
        uint y = 0;
        uint z = 0;
        for (uint i = 0; i < 32; i++) {
            x = x | uint(s[31-i]) << i * 8;
            y = y | uint(s[63-i]) << i * 8;
            z = z | uint(s[95-i]) << i * 8;
        }
        return (x, y, z);
    }
}
