// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../ERC721.sol";

/**
 *
 * @title ERC721Enumerable                                   *
 *                                                           *
 * @dev This implements an optional extension of {ERC721}    *
 *      defined in the EIP that adds enumerability of all    *
 *      the token ids in the contract as well as all token   *
 *      ids owned by each account.                           *
 *                                                           *
 * @custom:security-contact tech@ninfa.io                    *
 *
 */
abstract contract ERC721Enumerable is ERC721 {
    /**
     * @notice Returns the token ID owned by `_owner` at a given index.
     * @dev Throws if `_owner` is not the owner of the token at `_index`.
     * @param _owner The owner of the tokens.
     * @param _index The index to query.
     * @return The token ID owned by `_owner` at `_index`.
     */
    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256) {
        require(_owner == ownerOf(_index));
        return _index;
    }

    /**
     * @notice Returns the total supply of tokens.
     * @dev A count of valid NFTs tracked by this contract, where each one of them has an assigned and queryable owner
     * not equal to the zero address.
     * @return The total supply of tokens.
     */
    function totalSupply() external view returns (uint256) {
        return _owners.length;
    }

    /**
     * @notice Returns the token ID at a given index.
     * @dev Throws if `_index` >= `totalSupply()`.
     * @param _index A counter less than `totalSupply()`.
     * @return The token identifier for the `_index`th NFT, (sort order not specified).
     */
    function tokenByIndex(uint256 _index) external view returns (uint256) {
        require(_exists(_index));
        return _index;
    }
}
