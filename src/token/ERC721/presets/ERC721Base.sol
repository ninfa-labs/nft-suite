// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../extensions/ERC721Enumerable.sol";
import "../extensions/ERC721Metadata_URI.sol";
import "../extensions/ERC721Royalty.sol";
import "../extensions/ERC721Burnable.sol";
import "src/access/AccessControl.sol";

/**
 * @title ERC721Base
 * @notice Self-sovereign ERC-721 minter preset
 * @dev {ERC721} token
 * @author cosimo.demedici.eth (https://github.com/ninfa-labs/nft-suite)
 */
contract ERC721Base is AccessControl, ERC721Burnable, ERC721Royalty, ERC721Metadata_URI, ERC721Enumerable {
    /**
     * @dev `MINTER_ROLE` is needed if the deployer wants to use or
     * allow other accounts to mint on their self-sovereign collection.
     * The value is the keccak256 hash of "MINTER_ROLE".
     */
    bytes32 internal constant MINTER_ROLE = 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;
    /**
     * @dev `CURATOR_ROLE` is a constant used for role-based access control.
     * The value is the keccak256 hash of "CURATOR_ROLE".
     */
    bytes32 internal constant CURATOR_ROLE = 0x850d585eb7f024ccee5e68e55f2c26cc72e1e6ee456acf62135757a5eb9d4a10;

    /**
     * @dev `_FACTORY` is a constant set at the deployment of the master contract.
     * It replaces the `initializer` modifier, reducing the cost of calling
     * `initialize` from the factory contract when a new clone is deployed.
     */
    address internal immutable _FACTORY;

    /**
     * @notice Initializes the contract with the address of the factory contract.
     * @param factory_ The address of the factory contract.
     */
    constructor(address factory_) {
        _FACTORY = factory_;
    }

    /**
     * @notice Mints a new token.
     * @dev The `_data` parameter should be in the following format/order:
     * `abi.encodePacked(bytes32 _tokenURI, address [] memory _royaltyRecipients, uint96[] memory _royaltyBps`.
     * @param _to is not only the recipient, but also the address that will be used for access control when
     * calling the `setRoyaltyInfo` function. Therefore, `_to` MUST be an address controlled by the artist/minter to
     * prevent unauthorized changes to the
     * royalty info. When minted for the first time, the royalty recipient MUST be set to
     * msg.sender, i.e., the minter/artist. The royalty recipient cannot and SHOULD NOT be set to an address
     * different than the minter's, such as a payment splitter, or else the `setRoyaltyRecipient` function will revert
     * when called.
     */
    function mint(address _to, bytes memory _data) external onlyRole(MINTER_ROLE) {
        _mint(_to, _owners.length, _data);
    }

    /**
     * @dev required solidity override to ensure that the contract is initialized.
     * @notice Calls parent functions from the most derived to the most base contract: ERC721Metadata_URI,
     * ERC721Royalty, ERC721.
     * @dev This is an internal function that is meant to be overridden by derived contracts.
     */
    function _mint(
        address _to,
        uint256 _id,
        bytes memory _data
    )
        internal
        override(ERC721Metadata_URI, ERC721Royalty, ERC721)
    {
        super._mint(_to, _id, _data);
    }

    /**
     * @notice Burns a token and deletes its royalty info from storage.
     * @dev Overrides the `_burn` function of the base contract and all extensions.
     */
    function _burn(uint256 _tokenId) internal override(ERC721Royalty, ERC721Metadata_URI, ERC721) {
        super._burn(_tokenId);
    }

    /**
     * @notice Initializes the contract by setting roles and default values.
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `CURATOR_ROLE`, and `MINTER_ROLE` to the account that deploys the contract.
     * `MINTER_ROLE` is needed if the deployer wants to use or allow other accounts to mint.
     * `CURATOR_ROLE` is needed for artist managing roles such as galleries or curators.
     * @param _data Parameters MUST be encoded in the following order: `abi.encode(deployer, defaultRoyaltyBps, symbol,
     * name)`.
     * The `name` string is passed to the overridden initialize function as data bytes.
     */
    function initialize(bytes memory _data) public virtual {
        require(msg.sender == _FACTORY);

        (address deployer, uint96 defaultRoyaltyBps, string memory symbol_, string memory name_) =
            abi.decode(_data, (address, uint96, string, string));
        symbol = symbol_;
        _name = name_;

        _setDefaultRoyalty(deployer, defaultRoyaltyBps);

        _grantRole(DEFAULT_ADMIN_ROLE, deployer);
        _grantRole(CURATOR_ROLE, deployer);
        _grantRole(MINTER_ROLE, deployer);
        _setRoleAdmin(MINTER_ROLE, CURATOR_ROLE);
    }

    /**
     * @notice Sets the default royalty for the contract.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @param _receiver The account that will receive the royalty payments.
     * @param _feeNumerator The percentage of the sales price that will be paid as a royalty.
     */
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /**
     * @notice Sets the royalty for a specific token.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @param _tokenId The ID of the token for which to set the royalty.
     * @param _receiver The account that will receive the royalty payments.
     * @param _feeNumerator The percentage of the sales price that will be paid as a royalty.
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

    /**
     * @notice Sets the base URI for the contract.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @param baseURI_ The new base URI.
     */
    function setBaseURI(string calldata baseURI_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setBaseURI(baseURI_);
    }

    /**
     * @notice Checks if a token exists.
     * @param _id The ID of the token to check.
     * @return `true` if the token exists, `false` if it does not.
     */
    function exists(uint256 _id) external view returns (bool) {
        return _exists(_id);
    }

    /**
     * @notice Checks if the contract supports an interface.
     * @param interfaceId The interface ID to check for.
     * @return `true` if the contract supports the interface, `false` if it does not.
     */
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 // type(IERC165).interfaceId
            || interfaceId == 0x80ac58cd // type(IERC721).interfaceId
            || interfaceId == 0x780e9d63 // type(IERC721Enumerable).interfaceId
            || interfaceId == 0x5b5e139f // type(IERC721Metadata).interfaceId
            || interfaceId == 0x2a55205a // type(IERC2981).interfaceId
            || interfaceId == 0x7965db0b; // type(IAccessControl).interfaceId;
    }
}
