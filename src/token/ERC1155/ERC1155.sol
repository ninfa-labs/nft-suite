// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./IERC1155Receiver.sol";
import { IERC1155Errors } from "../common/IERC6093.sol";

/**
 *
 * @title ERC1155                                            *
 *                                                           *
 * @notice Gas efficient standard ERC1155 implementation.    *
 *                                                           *
 * @author Fork of solmate ERC1155                           *
 *      https://github.com/Rari-Capital/solmate/             *
 *                                                           *
 * @dev includes `_totalSupply` array needed in order to     *
 *      implement a maxSupply limit for lazy minting         *
 *                                                           *
 */
contract ERC1155 is IERC1155Errors {
    /**
     * @dev Emitted when `value` tokens of token type `id` are moved from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    /**
     * @dev Emitted when multiple tokens are moved from `from` to `to` by `operator`. `ids` and `values` are arrays
     * where each element corresponds to the token type and amount being transferred.
     */
    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values
    );
    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its tokens.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    /**
     * @dev Emitted when the URI for token type `id` changes to `value`.
     */
    event URI(string value, uint256 indexed id);

    /*----------------------------------------------------------*|
    |*  # ERC-1155 STORAGE LOGIC                                *|
    |*----------------------------------------------------------*/

    /**
     * @dev Mapping from token holder to token ID to balance.
     */
    mapping(address => mapping(uint256 => uint256)) internal _balanceOf;
    /**
     * @dev Mapping from token holder to operator approvals.
     */
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*----------------------------------------------------------*|
    |*  # ERC-1155 LOGIC                                        *|
    |*----------------------------------------------------------*/

    /**
     * @dev Sets or unsets the approval of a given operator.
     * @param operator Address to be approved.
     * @param approved Boolean value for approval.
     */
    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     * @param from Source address.
     * @param to Target address.
     * @param id ID of the token type.
     * @param amount Number of tokens to transfer.
     * @param data Additional data with no specified format.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external {
        require(msg.sender == from || isApprovedForAll[from][msg.sender]);

        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev Same as {safeTransferFrom} but internal in order for derived contract to call it without restrictions,
     * avoiding code repetition.
     */
    function _safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) internal {
        _balanceOf[from][id] -= amount;
        _balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);
        // 0xf23a6e61 == IERC1155Receiver.onERC1155Received.selector
        require(
            to.code.length == 0
                ? to != address(0)
                : IERC1155Receiver(to).onERC1155Received(msg.sender, from, id, amount, data) == 0xf23a6e61
        );
    }

    /**
     * @dev Transfers `amounts` tokens of token types `ids` from `from` to `to`.
     * @param from Source address.
     * @param to Target address.
     * @param ids IDs of each token type.
     * @param amounts Number of tokens to transfer.
     * @param data Additional data with no specified format.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    )
        external
    {
        require(ids.length == amounts.length);

        require(msg.sender == from || isApprovedForAll[from][msg.sender]);

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 amount;

        for (uint256 i = 0; i < ids.length;) {
            id = ids[i];
            amount = amounts[i];

            _balanceOf[from][id] -= amount;
            _balanceOf[to][id] += amount;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : IERC1155Receiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data)
                    == IERC1155Receiver.onERC1155BatchReceived.selector
        );
    }

    /**
     * @dev Returns the balance of multiple token IDs for multiple owners.
     * @param owners Addresses to check balance of.
     * @param ids IDs of tokens to check balance of.
     * @return balances Array of balances.
     */
    function balanceOfBatch(
        address[] calldata owners,
        uint256[] calldata ids
    )
        external
        view
        returns (uint256[] memory balances)
    {
        require(owners.length == ids.length, "LENGTH_MISMATCH");

        balances = new uint256[](owners.length);

        // Unchecked because the only math done is incrementing
        // the array index counter which cannot possibly overflow.
        unchecked {
            for (uint256 i = 0; i < owners.length; ++i) {
                balances[i] = _balanceOf[owners[i]][ids[i]];
            }
        }
    }

    /**
     * @dev Returns the balance of `id` token for owner `_owner`.
     * @param _owner Address to check balance of.
     * @param _id ID of token to check balance of.
     * @return balance Balance of owner for the token.
     */
    function balanceOf(address _owner, uint256 _id) external view returns (uint256 balance) {
        balance = _balanceOf[_owner][_id];
    }

    /*----------------------------------------------------------*|
    |*  # INTERNAL MINT/BURN LOGIC                              *|
    |*----------------------------------------------------------*/

    /**
     * @dev Mints `tokenId` and transfers it to `to`. Doesn't support safe
     * transfers while minting, i.e. doesn't call
     * onErc721Received function because when minting the receiver is
     * msg.sender.
     * We don’t need to zero address check because msg.sender is never the
     * zero address.
     * Because the tokenId is always incremented, we don’t need to check if
     * the token exists already.
     * @param _to if different from `msg.sender` then it is considered an airdop
     * as the minter is simply a token
     * operator
     *
     * Emits a {TransferSingle} event.
     */
    function _mint(address _to, uint256 _id, uint256 _value, bytes memory _data) internal virtual {
        if (_to == address(0)) revert ERC1155InvalidReceiver(_to);

        unchecked {
            _balanceOf[_to][_id] += _value;
        }

        if (_to.code.length > 0) {
            // IERC1155Receiver.onERC1155Received.selector
            if (IERC1155Receiver(_to).onERC1155Received(msg.sender, address(0), _id, _value, _data) != 0xf23a6e61) {
                revert ERC1155InvalidReceiver(_to);
            }
        }

        emit TransferSingle(msg.sender, address(0), _to, _id, _value);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `from`.
     * Emits a {TransferSingle} event.
     * @param _from Address to burn tokens from.
     * @param _id ID of token to burn.
     * @param _value Amount of tokens to burn.
     */
    function _burn(address _from, uint256 _id, uint256 _value) internal virtual {
        // `require(fromBalance >= _value)` is implicitly enforced
        _balanceOf[_from][_id] -= _value;

        emit TransferSingle(msg.sender, _from, address(0), _id, _value);
    }
}
