// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

// import "./IERC1155.sol";

interface IERC1155Burnable { /* is IERC1155 */
    function burn(address _from, uint256 _id, uint256 _value) external;
    function burnBatch(address _from, uint256[] memory _ids, uint256[] memory _values) external;
}
