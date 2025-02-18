// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

interface IERC1155Supply {
    /**
     * @dev Total amount of tokens in with a given _id.
     * @dev > The total value transferred from address 0x0 minus the total value
     * transferred to 0x0 observed via the
     * TransferSingle and TransferBatch events MAY be used by clients and
     * exchanges to determine the “circulating
     * supply” for a given token ID.
     */
    function totalSupply(uint256 _id) external view returns (uint256);

    /**
     * @dev Amount of unique token ids in this collection, required in order to
     *      enumerate `_totalSupply` (or `_tokenURIs`)
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Indicates whether any token exist with a given _id, or not.
     *
     * Tokens can be managed by their owner or approved accounts via {approve}
     * or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function exists(uint256 _id) external view returns (bool);
}
