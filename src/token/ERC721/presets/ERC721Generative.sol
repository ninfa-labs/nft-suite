// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../extensions/ERC721Enumerable.sol";
import "../extensions/ERC721Metadata_URI_autoIncrementID.sol";
import "../extensions/ERC721Royalty.sol";
import "../extensions/ERC721Burnable.sol";
import "src/access/Owned.sol";
import "src/utils/Address.sol";
import "src/utils/cryptography/MerkleProofLib.sol";
import "src/utils/cryptography/SSTORE2.sol";

/**
 *                                                              *
 * @title ERC721Generative                                      *
 *                                                              *
 * @notice Self-sovereign ERC-721 Generative art minter preset  *
 *                                                              *
 * @author cosimo.demedici.eth                                  *
 *                                                              *
 */
contract ERC721Generative is
    Owned,
    ERC721Burnable,
    ERC721Royalty,
    ERC721Metadata_URI_autoIncrementID,
    ERC721Enumerable
{
    using SSTORE2 for bytes;
    using MerkleProofLib for bytes32[];
    using Address for address;

    /**
     * @notice Address of the factory contract
     */
    address private immutable FACTORY;
    /**
     * @notice Address of the deployed contract containing the script
     */
    address public scriptStorageAddress;
    /**
     * @notice Address to receive fees
     */
    address public feeRecipient;
    /**
     * @notice Amount of fees
     */
    uint256 public feeAmount;
    /**
     * @notice Time when the NFT drop will happen
     */
    uint256 public dropTime;
    /**
     * @notice Duration of the AL drop
     */
    uint256 public dropDurationAL;
    /**
     * @notice Duration of the public drop
     */
    uint256 public dropDurationPublic;
    /**
     * @notice Price for addresses in the allow list
     */
    uint256 public ALPrice;
    /**
     * @notice Price for the public
     */
    uint256 public publicPrice;
    /**
     * @notice Maximum supply of the NFT
     */
    uint256 public maxSupply;

    /**
     * @notice Modifier to check if the current time is before the drop start
     */
    modifier onlyBeforeDropStart() {
        require(block.timestamp < dropTime);
        _;
    }
    /**
     * @notice Modifier to check if the current time is before the AL drop end
     */

    modifier onlyBeforeALDropEnd() {
        require(block.timestamp < dropTime + dropDurationAL);
        _;
    }

    /**
     * @dev Constructor that sets the factory address.
     * @param factory_ of the factory contract constant set at deployment of master contract, replaces
     * `initializer` modifier reducing the cost of calling
     * `initialize` from the factory contract whenever a new clone is deployed.
     */
    constructor(address factory_) {
        FACTORY = factory_;
    }

    /**
     * @notice Merkle root for the whitelist
     */
    bytes32 public merkleRoot;

    /**
     * @notice Function to mint a new NFT.
     * @dev Mints a new NFT if the conditions are met. The conditions include checking the Merkle proof for the address,
     * checking if the value sent with the transaction matches the price, and checking if the maximum supply has not
     * been reached.
     * @param _to The address to mint the NFT to.
     * @param _merkleProof The Merkle proof for the address.
     * @param _data Additional data to accompany the mint function.
     * @return _tokenId The ID of the minted NFT.
     */
    function mint(
        address _to,
        bytes32[] calldata _merkleProof,
        bytes memory _data
    )
        external
        payable
        returns (uint256 _tokenId)
    {
        require(_owners.length < maxSupply);

        if (block.timestamp - dropTime < dropDurationAL) {
            bytes32 node = keccak256(abi.encodePacked(_to));
            require(_merkleProof.verify(merkleRoot, node));
            require(msg.value == ALPrice);
        } else if (block.timestamp - dropTime < dropDurationAL + dropDurationPublic) {
            require(msg.value == publicPrice);
        } else {
            revert();
        }

        _tokenId = _owners.length;

        _mint(_to, _owners.length, _data);
    }

    /*----------------------------------------------------------*|
    |*  # REQUIRED SOLIDITY OVERRIDES                           *|
    |*----------------------------------------------------------*/

    /**
     * @notice Overrides the _mint function of the base contract and all extensions
     * @dev Calls parent functions from the most derived to the most base contract: ERC721Metadata_URI, ERC721Royalty,
     * ERC721
     * @param _to The address to mint the NFT to.
     * @param _id The ID of the NFT to mint.
     * @param _data Additional data to accompany the mint function.
     */
    function _mint(address _to, uint256 _id, bytes memory _data) internal override(ERC721Royalty, ERC721) {
        super._mint(_to, _id, _data);
    }

    /**
     * @notice Overrides the _burn function of the base contract and all extensions
     * @dev Deletes royalty info from storage
     * @param _tokenId The ID of the NFT to burn.
     */
    function _burn(uint256 _tokenId) internal override(ERC721Royalty, ERC721) {
        super._burn(_tokenId);
    }

    /*----------------------------------------------------------*|
    |*  # ADMIN                                                 *|
    |*----------------------------------------------------------*/

    /**
     * @notice Withdraws the contract balance to the fee recipient and the owner
     * @dev No need to add non reentrant modifier as the feeRecipient is set by the owner we assume it is a trusted
     * address
     */
    function withdraw() external {
        feeRecipient.sendValue(address(this).balance * feeAmount / 10_000);
        owner.sendValue(address(this).balance);
    }

    /**
     * @notice Sets the script for the contract
     * @dev Only callable by the owner before the drop start
     * @param _script The script to set
     */
    function setScript(bytes calldata _script) external onlyBeforeDropStart onlyOwner {
        scriptStorageAddress = SSTORE2.write(_script);
    }

    /**
     * @notice Sets the Merkle root for the contract
     * @dev Only callable by the owner
     * @param _merkleRoot The Merkle root to set
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    /**
     * @notice Sets the base URI for the contract
     * @dev Only callable by the owner
     * @param baseURI_ The base URI to set
     * @param deployedContract_ The address of the deployed contract
     */
    function setBaseURI(string memory baseURI_, address deployedContract_) external onlyOwner {
        _setBaseURI(baseURI_, deployedContract_);
    }

    /**
     * @notice Sets the drop time for the contract
     * @dev Only callable by the owner before the AL drop end
     * @param _newDropTime The new drop time to set
     */
    function setDropTime(uint256 _newDropTime) external onlyOwner onlyBeforeALDropEnd {
        require(block.timestamp < _newDropTime); // New drop time is in the future

        dropTime = _newDropTime;
    }

    /**
     * @notice Sets the maximum supply for the contract
     * @dev Only callable by the owner before the drop start
     * @param maxSupply_ The new maximum supply to set
     */
    function setMaxSupply(uint256 maxSupply_) external onlyOwner onlyBeforeDropStart {
        maxSupply = maxSupply_;
    }

    /**
     * @notice Sets the AL drop duration for the contract
     * @dev Only callable by the owner before the AL drop end
     * @param _newDropDurationAL The new AL drop duration to set
     */
    function setDropDurationAL(uint256 _newDropDurationAL) external onlyOwner onlyBeforeALDropEnd {
        require(block.timestamp < dropTime + _newDropDurationAL); // AL drop ends in the future

        dropDurationAL = _newDropDurationAL;
    }

    /**
     * @notice Sets the public drop duration for the contract
     * @dev Only callable by the owner
     * @param _newDropDurationPublic The new public drop duration to set
     */
    function setDropDurationPublic(uint256 _newDropDurationPublic) external onlyOwner {
        uint256 dropTimePublic = dropTime + dropDurationAL;
        require(block.timestamp < dropTimePublic + dropDurationPublic); // only before drop ended
        require(block.timestamp < dropTimePublic + _newDropDurationPublic); // Public drop ends in the future

        dropDurationPublic = _newDropDurationPublic;
    }

    /**
     * @notice Sets the AL price for the contract
     * @dev Only callable by the owner before the drop start
     * @param ALPrice_ The new AL price to set
     */
    function setALPrice(uint256 ALPrice_) external onlyOwner onlyBeforeDropStart {
        ALPrice = ALPrice_;
    }

    /**
     * @notice Sets the public price for the contract
     * @dev Only callable by the owner before the drop start
     * @param publicPrice_ The new public price to set
     */
    function setPublicPrice(uint256 publicPrice_) external onlyOwner onlyBeforeDropStart {
        publicPrice = publicPrice_;
    }

    /**
     * @notice Sets the fee recipient for the contract
     * @dev Only callable by the owner
     * @param feeRecipient_ The new fee recipient to set
     */
    function setFeeRecipient(address feeRecipient_) external onlyOwner {
        feeRecipient = feeRecipient_;
    }

    /**
     * @notice Sets the fee amount for the contract
     * @dev Only callable by the owner
     * @param feeAmount_ The new fee amount to set
     */
    function setFeeAmount(uint256 feeAmount_) external onlyOwner {
        feeAmount = feeAmount_;
    }

    /**
     * @notice Sets the default royalty for the contract
     * @dev Only callable by the owner
     * @param _receiver The address to receive the royalty
     * @param _feeNumerator The fee numerator for the royalty
     */
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external onlyOwner {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /**
     * @notice Sets the royalty for a specific token
     * @dev Only callable by the owner
     * @param _tokenId The ID of the token
     * @param _receiver The address to receive the royalty
     * @param _feeNumerator The fee numerator for the royalty
     */
    function setTokenRoyalty(uint256 _tokenId, address _receiver, uint96 _feeNumerator) external onlyOwner {
        _setTokenRoyalty(_tokenId, _receiver, _feeNumerator);
    }

    /*----------------------------------------------------------*|
    |*  # VIEW FUNCTIONS                                        *|
    |*----------------------------------------------------------*/

    /**
     * @dev Checks if a token exists.
     * @param _id The token ID to check.
     * @return A boolean indicating if the token exists.
     */
    function exists(uint256 _id) external view returns (bool) {
        return _exists(_id);
    }

    /**
     * @dev Reads the script from the contract.
     * @return The script as a string.
     */
    function getScript() external view returns (string memory) {
        return string(SSTORE2.read(scriptStorageAddress));
    }

    /*----------------------------------------------------------*|
    |*  # ERC-165                                               *|
    |*----------------------------------------------------------*/

    /**
     * @dev Checks if the contract supports a given interface.
     * @param interfaceId The interface ID to check.
     * @return A boolean indicating if the contract supports the interface.
     */
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 // type(IERC165).interfaceId
            || interfaceId == 0x80ac58cd // type(IERC721).interfaceId
            || interfaceId == 0x780e9d63 // type(IERC721Enumerable).interfaceId
            || interfaceId == 0x5b5e139f // type(IERC721Metadata).interfaceId
            || interfaceId == 0x2a55205a; // type(IERC2981).interfaceId
    }

    /*----------------------------------------------------------*|
    |*  # INITIALIZATION                                        *|
    |*----------------------------------------------------------*/

    /**
     * @dev Fallback function that allows the contract to receive funds.
     */
    receive() external payable { }

    /**
     * @dev Initializes the contract, setting the initial state and granting roles.
     * @param _data The initialization data.
     */
    function initialize(bytes calldata _data) external {
        require(msg.sender == FACTORY);
        bytes memory _script;
        string memory baseURI_;
        (
            _name,
            symbol,
            baseURI_,
            merkleRoot,
            dropTime,
            ALPrice,
            publicPrice,
            dropDurationAL,
            dropDurationPublic,
            maxSupply,
            feeAmount,
            feeRecipient,
            _script
        ) = abi.decode(
            _data,
            (
                string,
                string,
                string,
                bytes32,
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                address,
                bytes
            )
        );

        owner = tx.origin;
        emit OwnershipTransferred(address(0), tx.origin);

        _setBaseURI(baseURI_, address(this));
        _setDefaultRoyalty(owner, 1000); // set default royalty shares to 10%

        scriptStorageAddress = SSTORE2.write(_script);
    }
}
