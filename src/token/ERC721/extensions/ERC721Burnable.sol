// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../ERC721.sol";

/**
 * @title ERC721 Burnable Token
 * @dev ERC721 Token that can be burned (destroyed).
 */
abstract contract ERC721Burnable is ERC721 {
    /**
     * @notice Burns a specific token.
     * @dev The caller must own `tokenId` or be an approved operator.
     * @param _tokenId The token ID to burn.
     */
    function burn(uint256 _tokenId) external {
        require(_isApprovedOrOwner(msg.sender, _tokenId));
        _burn(_tokenId);
    }
}
