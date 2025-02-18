// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./ERC1155Base.sol";
import "src/utils/Address.sol";

/**
 * @title ERC1155OpenEdition                                    *
 *                                                              *
 * @notice A self-sovereign ERC-1155 minter preset.             *
 *                                                              *
 * @dev This ERC1155 token features minting and lazy minting.   *
 *                                                              *
 * @author cosimo.demedici.eth                                  *
 *                                                              *
 */
contract ERC1155OpenEdition is ERC1155Base {
    using Address for address;

    /**
     * @notice Mapping of token ID to order details.
     */
    mapping(uint256 => _Order) public orders;

    /**
     * @notice Structure to hold order details.
     */
    struct _Order {
        uint256 unitPrice;
        uint256 mintEnd;
        uint256 maxSupply;
        address from;
    }

    /**
     * @dev Mints new tokens for open editions. This function creates a new tokenId with an URI increasing totalSupply.
     * @param unitPrice The price per unit of the token.
     * @param mintEnd The end time for minting.
     * @param maxSupply The maximum supply of the token.
     * @param _data The data bytes containing token URI, royalty recipient and royalty BPS.
     */
    function mint(
        uint256 unitPrice,
        uint256 mintEnd,
        uint256 maxSupply,
        bytes calldata _data
    )
        external
        onlyRole(MINTER_ROLE)
    {
        uint256 tokenId = totalSupply();
        orders[tokenId] = _Order(unitPrice, mintEnd, maxSupply, msg.sender);
        // _mint(msg.sender, tokenId, 0, _data);

        _totalSupply.push(0);

        (bytes32 tokenURI, address royaltyRecipient, uint96 royaltyBps) = abi.decode(_data, (bytes32, address, uint96));

        _tokenURIs[tokenId] = tokenURI;

        if (royaltyBps > 0) {
            // _setTokenRoyalty reverts if royaltyRecipient is address(0)
            _setTokenRoyalty(tokenId, royaltyRecipient, royaltyBps);
        }

        emit TransferSingle(msg.sender, address(0), msg.sender, tokenId, 0);
    }

    /**
     * @dev Mints a desired tokenId value and pays the creator for the primary sale. This function is called by
     * collectors.
     * @param _to The address to mint the tokens to.
     * @param _value The amount of tokens to mint.
     * @param _tokenId The ID of the token to mint.
     * @param _data The data bytes.
     */
    function mint(address _to, uint256 _value, uint256 _tokenId, bytes calldata _data) external payable {
        _Order memory order = orders[_tokenId];
        // token must be minted in order to prevent unauthorized pre-minting
        require(exists(_tokenId));
        // cannot mint more than maxSupply
        require(_value <= order.maxSupply - totalSupply(_tokenId));
        // pay in the correct amount
        require(msg.value == order.unitPrice * _value);
        // mint end time must not be expired
        // mintEnd must have a positive value in order to prevent collectors from calling this function
        // on tokenIds with no associated order (minted normally). Since timestamp is always positive, will revert if
        // mintEnd is 0.
        require(order.mintEnd > block.timestamp);
        // fetch the sales fee info from the factory contract
        (bool success, bytes memory returnData) =
            FACTORY.call(abi.encodeWithSignature("salesFeeInfo(uint256)", msg.value));
        require(success);
        // unpack the return data
        (address feeRecipient, uint256 feeAmount) = abi.decode(returnData, (address, uint256));
        // send the fee to the feeRecipient
        feeRecipient.sendValue(feeAmount);
        // send the rest to the creator
        order.from.sendValue(address(this).balance);

        unchecked {
            _totalSupply[_tokenId] += _value;
        }
        // forward any data for erc1155Recipient interface if any, calls {ERC1155-mint}
        ERC1155._mint(_to, _tokenId, _value, _data);
    }

    /*----------------------------------------------------------*|
    |*  # ORDER SETTINGS                                        *|
    |*----------------------------------------------------------*/

    /**
     * @notice may be called in order to delay the mint end or to cut it short
     * @dev there are not requirements meaning that it may be colled even during or after an open edition's sale period
     * @param _tokenId The ID of the token.
     * @param _newTimestamp if set to a lower number than block.timestamp (ideally 0 for consistency) it is equivalent
     * to pausing a tokenId's minting,
     * until the timestamp is reset in the future
     */
    function setMintEnd(uint256 _tokenId, uint256 _newTimestamp) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _Order storage order = orders[_tokenId];
        order.mintEnd = _newTimestamp;
    }

    /**
     * @dev Sets the price per unit of the token. The contract admin can reset orders' price at any time, i.e. even
     * after minting has begun.
     * @param _tokenId The ID of the token.
     * @param _newUnitPrice The new price per unit.
     */
    function setUnitPrice(uint256 _tokenId, uint256 _newUnitPrice) external onlyRole(DEFAULT_ADMIN_ROLE) {
        orders[_tokenId].unitPrice = _newUnitPrice;
    }

    /**
     * @dev Sets the maximum supply of the token.
     * @param _tokenId The ID of the token.
     * @param _newMaxSupply The new maximum supply.
     */
    function setMaxSupply(uint256 _tokenId, uint256 _newMaxSupply) external onlyRole(DEFAULT_ADMIN_ROLE) {
        orders[_tokenId].maxSupply = _newMaxSupply;
    }

    /**
     * @dev The constructor function.
     * @param factory_ The address of the factory.
     */
    constructor(address factory_) ERC1155Base(factory_) { }
}
