// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../ERC1155.sol";
import "../../common/DecodeTokenURI.sol";
import "../../common/Metadata.sol";

/**
 * @dev ERC1155 token with storage based token URI management.
 */
abstract contract ERC1155Metadata_URI is ERC1155, Metadata {
    using DecodeTokenURI for bytes;

    /**
     * @notice Returns the URI for token type `tokenId`.
     * @dev Throws if `_tokenURIs[tokenId]` is not set.
     * @param tokenId The token ID to query.
     * @return The URI of the token.
     */
    function uri(uint256 tokenId) public view returns (string memory) {
        require(_tokenURIs[tokenId] != 0x00);
        return string( // once hex decoded base58 is converted to string, we get
            // the initial IPFS hash
            abi.encodePacked(
                _baseURI,
                abi.encodePacked(bytes2(0x1220), _tokenURIs[tokenId]) // full
                    // bytes of base58 + hex encoded IPFS hash
                    // example.
                    // prepending 2 bytes IPFS hash identifier that was removed
                    // before storing the hash in order to
                    // fit in bytes32. 0x1220 is "Qm" base58 and hex encoded
                    // bytes32(tokenId) // tokenURI (IPFS hash) with its first 2
                    // bytes truncated, base58 and hex
                    // encoded returned as bytes32
                    .toBase58()
            )
        );
    }

    /**
     * @notice Mints a new token with a tokenURI.
     * @dev This internal function MUST only be called in order to mint a new token with a tokenURI,
     * i.e. not used to increment the supply of an existing token.
     * This matters because the tokenURI MUST be set before transferring the control flow to _mint.
     * @param _to The address to mint the token to.
     * @param _tokenId The token ID; the child/derived contract is responsible for calculating it.
     * @param _value The amount of tokens to mint.
     * @param _data The data to associate with the token.
     */
    function _mint(address _to, uint256 _tokenId, uint256 _value, bytes memory _data) internal virtual override {
        (bytes32 tokenURI, bytes memory remainingData) = abi.decode(_data, (bytes32, bytes));

        /// @dev token URI MUST be set before transfering the control flow to _mint, which could include
        /// external calls, which could result in reentrancy.
        /// E.g. https://medium.com/chainsecurity/totalsupply-inconsistency-in-erc1155-nft-tokens-8f8e3b29f5aa
        _tokenURIs[_tokenId] = tokenURI;

        super._mint(_to, _tokenId, _value, remainingData);
    }

    /**
     * @notice Sets the base URI.
     * @dev Child contract MAY require access control to the external function implementation.
     * @param baseURI_ The new base URI.
     */
    function _setBaseURI(string calldata baseURI_) internal {
        _baseURI = baseURI_;
    }
}
