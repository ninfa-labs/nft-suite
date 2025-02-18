// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "src/access/AccessControl.sol";
import "src/utils/Address.sol";
import "../extensions/ERC1155Supply.sol";
import "../extensions/ERC1155Metadata_URI.sol";
import "../extensions/ERC1155Royalty.sol";
import "../extensions/ERC1155Burnable.sol";

/**
 *
 * @title ERC1155Base                                        *
 *                                                           *
 * @notice Self-sovereign ERC-1155 minter preset             *
 *                                                           *
 * @author cosimo.demedici.eth                               *
 *                                                           *
 */
contract ERC1155Base is AccessControl, ERC1155Burnable, ERC1155Royalty, ERC1155Metadata_URI, ERC1155Supply {
    /*----------------------------------------------------------*|
    |*  # ACCESS CONTROL                                        *|
    |*----------------------------------------------------------*/

    /**
     * @dev `MINTER_ROLE` is needed in case the deployer may want to use or
     * allow other accounts to mint on their self-sovereign collection.
     */
    bytes32 internal constant MINTER_ROLE = 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;
    /**
     * @dev `CURATOR_ROLE` is needed in case the deployer may want to use or
     * allow other accounts to curate on their self-sovereign collection.
     */
    bytes32 internal constant CURATOR_ROLE = 0x850d585eb7f024ccee5e68e55f2c26cc72e1e6ee456acf62135757a5eb9d4a10;

    /**
     * @dev Constant set at deployment of master contract, replaces
     * `initializer` modifier reducing the cost of calling
     * `initialize` from the factory contract when a new clone is deployed.
     */
    address internal immutable FACTORY;

    /*----------------------------------------------------------*|
    |*  # MINTING                                               *|
    |*----------------------------------------------------------*/

    /**
     * @notice Creates `amount` new tokens for `to`, of token type `id`.
     * @dev mint() cannot be called in order to increase the supply of an existing token Id,
     * this is in order to avoid a very complex contract logic for establishing a maximum supply cap per token.
     * I.e. the maximum tokenId supply is implicitly enforced by the fact that a new tokenId is created each time
     * mint() is called.
     * @param _to if different from msg.sender it is considered an airdrop
     * @param _data is used to pass the tokenURI which is the ipfs hash of the token,
     * base58 decoded, then the first two bytes "Qm" removed,  then hex
     * encoded and in order to fit exactly in 32 bytes (uint256 is 32 bytes).
     *
     * const getBytes32FromIpfsHash = hash => {
     *      let bytes = bs58.decode(hash);
     *      bytes = bytes.slice(2, bytes.length);
     *      let hexString = web3.utils.bytesToHex(bytes);
     *      return web3.utils.hexToNumber(hexString);
     *  };
     *
     */
    function mint(address _to, uint256 _value, bytes calldata _data) external onlyRole(MINTER_ROLE) {
        _mint(_to, totalSupply(), _value, _data);
    }

    /**
     * @dev super._mint calls parent functions from the most derived to the most base contract: ERC1155Supply,
     * ERC1155Metadata_URI, ERC1155
     */
    function _mint(
        address _to,
        uint256 _tokenId,
        uint256 _value,
        bytes memory _data
    )
        internal
        override(ERC1155Supply, ERC1155Metadata_URI, ERC1155Royalty, ERC1155)
    {
        super._mint(_to, _tokenId, _value, _data);
    }

    /*----------------------------------------------------------*|
    |*  # BURN                                                  *|
    |*----------------------------------------------------------*/

    /**
     * @notice Burns `_value` tokens of token type `_tokenId` from `_from`.
     * @dev Required override by Solidity.
     * @dev Overrides _burn function of base contract and all extensions.
     * @dev Deletes royalty info from storage, this is to avoid the need of a contract extension to override the _burn
     * function in order to delete token royalty info.
     */
    function _burn(
        address _from,
        uint256 _tokenId,
        uint256 _value
    )
        internal
        override(ERC1155Supply, ERC1155Royalty, ERC1155)
    {
        super._burn(_from, _tokenId, _value);
    }

    /*----------------------------------------------------------*|
    |*  # ERC-165                                               *|
    |*----------------------------------------------------------*/

    /**
     * @notice Checks if the contract supports a given interface.
     * @dev Returns true if the contract supports the interface with the given ID, false otherwise.
     * @param interfaceId The ID of the interface to check.
     */
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 // Interface ID for IERC165
            || interfaceId == 0xd9b67a26 // Interface ID for IERC1155
            || interfaceId == 0x2a55205a // Interface ID for IERC2981
            || interfaceId == 0x0e89341c // Interface ID for IERC1155MetadataURI
            || interfaceId == 0x7965db0b; // Interface ID for IAccessControl
    }

    /*----------------------------------------------------------*|
    |*  # SETUP                                                 *|
    |*----------------------------------------------------------*/

    /**
     * @notice Initializes the contract.
     * @dev Sets the `symbol`, `_name`, and default royalties, and grants roles.
     * @param _data The data to initialize the contract with.
     */
    function initialize(bytes memory _data) public virtual {
        require(msg.sender == FACTORY);

        (address deployer, uint96 defaultRoyaltyBps, string memory symbol_, string memory name_) =
            abi.decode(_data, (address, uint96, string, string));
        symbol = symbol_;
        _name = name_;

        // set default royalties
        _setDefaultRoyalty(deployer, defaultRoyaltyBps);

        _grantRole(DEFAULT_ADMIN_ROLE, deployer);
        _grantRole(CURATOR_ROLE, deployer);
        _grantRole(MINTER_ROLE, deployer);

        _setRoleAdmin(MINTER_ROLE, CURATOR_ROLE);
    }

    /*----------------------------------------------------------*|
    |*  # ROYALTY INFO SETTER                                   *|
    |*----------------------------------------------------------*/

    /**
     * @notice Sets the default royalty for the contract.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @param _receiver The account to receive the royalty.
     * @param _feeNumerator The numerator of the royalty fee.
     */
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /**
     * @notice Sets the royalty for a specific token.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @param _tokenId The ID of the token to set the royalty for.
     * @param _receiver The account to receive the royalty.
     * @param _feeNumerator The numerator of the royalty fee.
     */
    function setTokenRoyalty(
        uint256 _tokenId,
        address _receiver,
        uint96 _feeNumerator
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setTokenRoyalty(_tokenId, _receiver, _feeNumerator);
    }

    /*----------------------------------------------------------*|
    |*  # URI STORAGE                                           *|
    |*----------------------------------------------------------*/

    /**
     * @notice Sets the base URI for the contract.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @param baseURI_ The new base URI.
     */
    function setBaseURI(string calldata baseURI_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setBaseURI(baseURI_);
    }

    /**
     * @notice Creates `DOMAIN_SEPARATOR` and `VOUCHER_TYPEHASH` and assigns
     * address to `FACTORY`.
     * @dev `factory_` is used for access control on self-sovereign ERC-1155
     * collection rather than using the `initializer` modifier,
     * this is cheaper because the clones won't need to write `initialized = true;` to storage each time they are
     * initialized. Instead `FACTORY` is only assigned once in the `constructor` of the master copy therefore it can be
     * read by all clones.
     * @param factory_ The factory address.
     */
    constructor(address factory_) {
        FACTORY = factory_;
    }
}
