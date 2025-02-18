// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import "./IERC1155.sol";

interface IERC1155Metadata_URI is IERC1155 {
    /**
     * @notice A distinct Uniform Resource Identifier (URI) for a given token.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     * @dev URIs are defined in RFC 3986.
     * The URI MUST point to a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema".
     * @return URI string Rfor token type `id`.
     */
    function uri(uint256 id) external view returns (string memory);
}
