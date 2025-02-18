// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../ERC1155.sol";

/**
 * @dev Extension of ERC1155 that adds tracking of total supply per id.
 *
 * Useful for scenarios where Fungible and Non-fungible tokens have to be
 * clearly identified. Note: While a totalSupply of 1 might mean the
 * corresponding is an NFT, there is no guarantees that no other token with the
 * same id are not going to be minted.
 *
 */
contract ERC1155Supply is ERC1155 {
    /**
     * @dev keeps track of per-token id's total supply, as well as overall
     * supply.
     *      also used as a counter when minting, by reading the .length property
     * of the array.
     */
    uint256[] internal _totalSupply;

    /**
     * @notice Returns the total supply of a specific token ID.
     * @dev The total value transferred from address 0x0 minus the total value transferred to 0x0 observed via the
     * TransferSingle and TransferBatch events MAY be used by clients and exchanges to determine the “circulating
     * supply” for a given token ID.
     * @param _id The token ID to query.
     * @return The total supply of the token.
     */
    function totalSupply(uint256 _id) public view returns (uint256) {
        return _totalSupply[_id];
    }

    /**
     * @notice Returns the total number of unique token IDs in this collection.
     * @dev Required in order to enumerate `_totalSupply` (or `_tokenURIs`, see {ERC1155Metadata_URI-uri}) from a
     * client.
     * @return The total number of unique token IDs.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply.length;
    }

    /**
     * @notice Checks if a token exists with a given ID.
     * @dev Note that for implementations such as open editions, token IDs with a supply of 0 may exist, i.e. minting
     * with 0 supply may be intentional.
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     * Tokens start existing when they are minted (`_mint`), and stop existing when they are burned (`_burn`).
     * @param _id The token ID to check.
     * @return True if the token exists, false otherwise.
     */
    function exists(uint256 _id) public view returns (bool) {
        return _id < _totalSupply.length;
    }

    /**
     * @notice Mints a new token.
     * @dev Because _mint is never (and MUST not be) invoked in order to mint additional supply for an existing tokenId,
     * it is more efficient to push a new element into the array rather than writing to an arbitrary index such as
     * `_totalSupply[_id] += _totalSupply`. For this reason it was named more aptly `_totalSupply`, rather than
     * `_value`.
     * @param _to The address to mint the token to.
     * @param _id The token ID; the child/derived contract is responsible for calculating it.
     * @param totalSupply_ The total supply for the new token.
     * @param _data The data to associate with the token.
     */
    function _mint(address _to, uint256 _id, uint256 totalSupply_, bytes memory _data) internal virtual override {
        /**
         * @dev totalSupply MUST be incremented before transfering the control flow to _mint, which could include
         * external calls, which could result in reentrancy.
         * E.g. https://medium.com/chainsecurity/totalsupply-inconsistency-in-erc1155-nft-tokens-8f8e3b29f5aa
         */
        _totalSupply.push(totalSupply_);

        super._mint(_to, _id, totalSupply_, _data);
    }

    /**
     * @notice Burns a specific token.
     * @dev Since _balanceOf has been decremented by the base contract _burn function by calling super._burn first,
     * and since the sum of balances can never exceed totalSupply, we can safely decrement totalSupply without requiring
     * to check for underflow.
     * Since there are no external calls being made in _burn, there is no risk of reentrancy that could exploit
     * _totalSupply.
     * @param _from The owner of the token.
     * @param _id The token ID to burn.
     * @param _value The amount of tokens to burn.
     */
    function _burn(address _from, uint256 _id, uint256 _value) internal virtual override {
        super._burn(_from, _id, _value);

        unchecked {
            /**
             * since _balanceOf has been decremented by the base contract _burn function by calling super._burn first,
             * and since the sum of balances can never exceed totalSupply, we can safely
             * decrement totalSupply without requiring to check for underflow.
             * Since there are no external calls being made in _burn, there is no risk of reentrancy that could exploit
             * _totalSupply
             */
            _totalSupply[_id] -= _value;
        }
    }
}
