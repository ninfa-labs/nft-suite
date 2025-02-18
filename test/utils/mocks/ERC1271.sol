pragma solidity 0.8.28;

contract ERC1271 {
    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;

    function isValidSignature(bytes32, bytes memory) public pure returns (bytes4 magicValue) {
        magicValue = MAGICVALUE;
    }
}
