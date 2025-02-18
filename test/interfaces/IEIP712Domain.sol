// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IEIP712Domain {
    function eip712Domain()
        external
        view
        returns (
            bytes1 _fields,
            string memory _name,
            string memory _version,
            uint256 _chainId,
            address _verifyingContract,
            bytes32 _salt,
            uint256[] memory _extensions
        );
}
