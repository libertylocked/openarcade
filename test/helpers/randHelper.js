import eutil from 'ethereumjs-util'

export function createCommit (num) { return eutil.bufferToHex(eutil.keccak256(eutil.setLengthLeft(num, 32))) }
