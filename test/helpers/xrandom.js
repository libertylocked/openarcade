// XRandom is an XOR-keccak256 RNG implementation in Javascript
const eutil = require('ethereumjs-util')
const bignum = require('bignum')

class XRandom {
  constructor (inputs = []) {
    this._seed = bignum(0)
    this.update(inputs)
  }

  next (bound) {
    this._current = bignum.fromBuffer(
      eutil.keccak256(eutil.setLengthLeft(this.current.toBuffer(), 32)))
    this._index = this._index.add(1)
    if (bound) {
      return this.current.mod(XRandom.toBignum(bound))
    }
    return this.current
  }

  update (inputs) {
    this._seed = this._seed.xor(
      inputs.map(XRandom.toBignum).reduce((seed, v) => seed.xor(v), bignum(0))
    )
    this._current = this._seed
    this._index = bignum(0)
  }

  get seed () {
    return this._seed
  }

  get current () {
    return this._current
  }

  get index () {
    return this._index
  }
}

XRandom.toBignum = (v) => {
  if (bignum.isBigNum(v)) {
    return v
  } else if (eutil.BN.isBN(v)) {
    // convert bignumber to bignum
    return bignum(v.toString(16), 16)
  } else if (typeof v === 'number') {
    return bignum(v)
  } else if (typeof v === 'string') {
    if (eutil.isHexPrefixed(v)) {
      return bignum(eutil.stripHexPrefix(v), 16)
    } else {
      return bignum(v, 10)
    }
  } else {
    throw new Error('Value must be a string, number, bignum, or bignumber')
  }
}

module.exports = XRandom
