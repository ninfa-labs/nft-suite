// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../ERC721.sol";
import "../../common/DecodeTokenURI.sol";
import "../../common/Metadata.sol";

/**
 * @title ERC721 token with storage based token URI management.
 * @dev This abstract contract provides functionality for managing URIs for ERC721 tokens.
 */
abstract contract ERC721Metadata_URI is ERC721, Metadata {
    using DecodeTokenURI for bytes;

    /**
     * @notice Returns the URI for token type `tokenId`.
     * @dev Throws if `_exists(tokenId)` is not true. The returned URI is the initial IPFS hash once the hex encoded
     * base58 is converted to string.
     * @param tokenId The token ID to query.
     * @return The URI of the token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_exists(tokenId));

        return string( // once hex encoded base58 is converted to string, we get
            // the initial IPFS hash
            abi.encodePacked(
                _baseURI,
                abi.encodePacked(bytes2(0x1220), _tokenURIs[tokenId]) // full
                    // bytes of base58 + hex encoded IPFS hash
                    // example.
                    // prepending 2 bytes IPFS hash identifier that was removed
                    // before storing the hash in order to
                    // fit in bytes32. 0x1220 is "Qm" base58 and hex encoded
                    // tokenURI (IPFS hash) with its first 2 bytes truncated,
                    // base58 and hex encoded returned as
                    // bytes32
                    .toBase58()
            )
        );
    }

    /**
     * @notice Mints a new token.
     * @dev In this extension's `_mint` function, it is possible (although unintended) to mint two tokens with the same
     * URI. This is because the derived contract's implementation is supposed to have access control so that only
     * whitelisted minters can mint, i.e. trusted input.
     * @param _to The address to receive the minted token.
     * @param _tokenId The token ID to mint.
     * @param _data The data bytes containing the token URI and any remaining data.
     */
    function _mint(address _to, uint256 _tokenId, bytes memory _data) internal virtual override {
        (bytes32 tokenURI_, bytes memory remainingData) = abi.decode(_data, (bytes32, bytes));

        /**
         * @dev token URI MUST be set before transfering the control flow to _mint, which could include
         * external calls, which could result in reentrancy.
         * E.g. https://medium.com/chainsecurity/totalsupply-inconsistency-in-erc1155-nft-tokens-8f8e3b29f5aa
         */
        _tokenURIs[_tokenId] = tokenURI_;

        super._mint(_to, _tokenId, remainingData);
    }

    /**
     * @notice Burns a token.
     * @dev See {ERC721-_burn}. Deletes the token URI upon burning.
     * @param _tokenId The token ID to burn.
     */
    function _burn(uint256 _tokenId) internal virtual override {
        delete _tokenURIs[_tokenId];

        super._burn(_tokenId);
    }

    /**
     * @notice Sets the base URI.
     * @dev This is an optional function that child contracts may require access control to the external function
     * implementation.
     * @param baseURI_ The base URI to set.
     */
    function _setBaseURI(string calldata baseURI_) internal {
        _baseURI = baseURI_;
    }
}
