// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 *
 * @title Metadata
 * @notice ERC-721 Metadata extension
 * @dev see https://eips.ethereum.org/EIPS/eip-1155#metadata-choices)
 *
 */
contract Metadata {
    /*----------------------------------------------------------*|
    |*  # ERC-721 METADATA (ERC-1155 OPTIONAL, non-standard)    *|
    |*----------------------------------------------------------*/

    /// @notice ERC-721 name
    string internal _name;
    /// @notice ERC-721 symbol
    string public symbol;

    /**
     * @dev Hardcoded base URI in order to remove the need for a constructor, it
     * can be set anytime by an admin
     * @dev URI MUST be an IPFSv1 hash
     */
    string internal _baseURI = "ipfs://";
    /**
     * @dev Optional mapping for token URIs.
     * @dev returns bytes32 IPFS hash
     * @dev only set when a new token is minted.
     * No need for a setter function, see
     * https://forum.openzeppelin.com/t/why-doesnt-openzeppelin-erc721-contain-settokenuri/6373
     * and
     * https://forum.openzeppelin.com/t/function-settokenuri-in-erc721-is-gone-with-pragma-0-8-0/5978/2
     */
    mapping(uint256 => bytes32) internal _tokenURIs;

    /// @notice getter function, see ERC721LazyMint and ERC1155LazyMint's `initialize` function as for why the getter is
    /// needed.
    function name() public virtual returns (string memory) {
        return _name;
    }
}
