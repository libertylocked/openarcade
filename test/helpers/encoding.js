import abi from 'ethereumjs-abi'
import eutil from 'ethereumjs-util'

const encodeFixedUintArray = (arr) => eutil.bufferToHex(
  abi.rawEncode(arr.map(() => 'uint256'), arr))

export {
  encodeFixedUintArray
}
