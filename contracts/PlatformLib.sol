pragma solidity 0.4.24;


library PlatformLib {
    function encodePoint1D(uint x)
        public pure
        returns (bytes)
    {
        return abi.encode(x);
    }

    function decodePoint1D(bytes s)
        public pure
        returns (uint)
    {
        require(s.length == 32);
        uint x = 0;
        for (uint i = 0; i < 32; i++) {
            x = x | uint(s[31-i]) << i * 8;
        }
        return x;
    }

    function encodePoint2D(uint x, uint y)
        public pure
        returns (bytes)
    {
        return abi.encode(x, y);
    }

    function decodePoint2D(bytes s)
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

    function encodePoint3D(uint x, uint y, uint z)
        public pure
        returns (bytes)
    {
        return abi.encode(x, y, z);
    }

    function decodePoint3D(bytes s)
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
