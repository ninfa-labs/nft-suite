// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

// import "./IERC1155.sol";

interface IERC1155Mintable { /* is IERC1155 */
    function mint(address _to, uint256 _value, bytes calldata _data) external;

    function mintBatch(address to, uint256[] memory amounts, bytes memory data) external;
}
