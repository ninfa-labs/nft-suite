// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../ERC1155.sol";

import "../../common/ERC2981.sol";

/**
 * @dev Extension of ERC721 with the ERC2981 NFT Royalty Standard, a
 * standardized way to retrieve royalty payment
 * information.
 */
abstract contract ERC1155Royalty is ERC2981, ERC1155 {
    /**
     * @notice Burns a specific token.
     * @dev This override additionally clears the royalty information for the token.
     * @param _from The owner of the token.
     * @param _tokenId The token ID to burn.
     * @param _value The amount of tokens to burn.
     */
    function _burn(address _from, uint256 _tokenId, uint256 _value) internal virtual override {
        _resetTokenRoyalty(_tokenId);
        super._burn(_from, _tokenId, _value);
    }

    /**
     * @notice Mints a new token.
     * @dev msg.sender cannot be assigned as royalty recipient because of lazy minting it may be the buyer.
     * Therefore it is necessary to pass royalty information as raw bytes in order to keep the function signature
     * unchanged.
     * @param _to The address to mint the token to.
     * @param _tokenId The token ID; the child/derived contract is responsible for calculating it.
     * @param _value The amount of tokens to mint.
     * @param _data The raw bytes of the royalty information and tokenURI, the first 32 bytes are the tokenURI.
     */
    function _mint(address _to, uint256 _tokenId, uint256 _value, bytes memory _data) internal virtual override {
        /**
         * @dev since _mint is never called in order to increase the supply of an existing token,
         * the _id is always new and therefore the royalty information is always new as well.
         * i.e. there is no need to check if _data is empty, as it is required to pass royalty information,
         * otherwise the token cannot be minted since the tx will revert with an index out of bounds error on the
         * following line.
         */
        (address royaltyRecipient, uint96 royaltyBps, bytes memory data) = abi.decode(_data, (address, uint96, bytes));
        /// @dev for security reasons, _setRoyaltyInfo() is called only if `royaltyBps` and `royaltyRecipient` are not 0
        if (royaltyBps > 0) {
            // _setTokenRoyalty reverts if royaltyRecipient is address(0)
            _setTokenRoyalty(_tokenId, royaltyRecipient, royaltyBps);
        }
        super._mint(_to, _tokenId, _value, data);
    }
}
