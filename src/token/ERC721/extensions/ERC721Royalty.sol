// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../ERC721.sol";
import "../../common/ERC2981.sol";

/**
 * @dev Extension of ERC721 with the ERC2981 NFT Royalty Standard, a
 * standardized way to retrieve royalty payment
 * information.
 */
abstract contract ERC721Royalty is ERC2981, ERC721 {
    /**
     * @notice Burns a specific token.
     * @dev This override additionally clears the royalty information for the token.
     * @param _tokenId The token ID to burn.
     */
    function _burn(uint256 _tokenId) internal virtual override {
        _resetTokenRoyalty(_tokenId);
        super._burn(_tokenId);
    }

    /**
     * @notice Mints a new token.
     * @dev For security reasons, _setRoyaltyInfo() is called only if `royaltyBps` and `royaltyRecipient` are not 0.
     * _setTokenRoyalty reverts if royaltyRecipient is address(0).
     * @param _to The address to mint the token to.
     * @param _tokenId The token ID; the child/derived contract is responsible for calculating it.
     * @param _data The data to associate with the token.
     */
    function _mint(address _to, uint256 _tokenId, bytes memory _data) internal virtual override {
        (address royaltyRecipient, uint96 royaltyBps, bytes memory data) = abi.decode(_data, (address, uint96, bytes));

        /// @dev for security reasons, _setRoyaltyInfo() is called only if `royaltyBps` and `royaltyRecipient` are not 0
        if (royaltyBps > 0) {
            // _setTokenRoyalty reverts if royaltyRecipient is address(0)
            _setTokenRoyalty(_tokenId, royaltyRecipient, royaltyBps);
        }

        super._mint(_to, _tokenId, data);
    }
}
