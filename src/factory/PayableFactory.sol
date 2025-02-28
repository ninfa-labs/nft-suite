// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./AbstractFactory.sol";
import "../access/Owned.sol";
import "../utils/Address.sol";

/**
 * @title PayableFactory
 * @notice Clone factory pattern contract without any access control but requiring a flat fee payment in order to deploy
 * clones, as long as they are cloned from a whitelisted master address.
 * @author cosimo.demedici.eth (https://github.com/ninfa-labs/nft-suite)
 */
contract PayableFactory is AbstractFactory, Owned {
    using Address for address payable;

    /**
     * @dev The flat fee for creating a new clone.
     */
    uint256 public cloningFee;

    /**
     * @dev The constructor sets role-based access control granting the factory deployer account both DEFAULT_ADMIN_ROLE
     * and the custom _CURATOR_ROLE.
     * @dev Fee information is set in the base {AbstractFactory-constructor
     * @param _feeNumerator The numerator of the fee fraction.
     * @param _feeRecipient The address to receive the fee.
     */
    constructor(uint256 _feeNumerator, address _feeRecipient) AbstractFactory(_feeNumerator, _feeRecipient) {
        owner = msg.sender;
        // emit event fired by Owned contract when the owner is set
        emit OwnershipTransferred(address(0), msg.sender);
        // set the factory fee to 0.05 ETH
        cloningFee = 50_000_000 gwei; // 50_000_000 gwei == 0.05 ETH
    }

    /**
     * @notice Clone function to create a new instance of a contract. This function is payable and requires a fee.
     * @param _instance The address of the instance to clone.
     * @param _salt A random number of our choice. Generated with
     * https://web3js.readthedocs.io/en/v1.2.11/web3-utils.html#randomhex
     * _salt could also be dynamically calculated in order to avoid duplicate
     * clones and for a way of finding predictable clones if salt the parameters are known.
     * @param _data The initialization data for the clone.
     * @return clone_ The address of the new clone.
     */
    function clone(address _instance, bytes32 _salt, bytes calldata _data) external payable returns (address clone_) {
        require(msg.value == cloningFee);

        clone_ = _cloneDeterministic(_instance, _salt, _data);
    }

    /**
     * @notice Sets the factory fee.
     * @param _newCloningFee The updated factory fee.
     */
    function setFactoryFee(uint256 _newCloningFee) external onlyOwner {
        cloningFee = _newCloningFee;
    }

    /**
     * @notice Whitelist or unwhitelist a master implementation.
     * @dev External visibility because it is meant to be needed by all derived contracts,
     * i.e. no point in having a public getter for it, to avoid extra code.
     * @param _instance Address of the master implementation to whitelist.
     * @param _isWhitelisted Bool to set the implementation as whitelisted or not.
     */
    function setMaster(address _instance, bool _isWhitelisted) external onlyOwner {
        _setMaster(_instance, _isWhitelisted);
    }

    /**
     * @dev see {AbstractFactory-salesFeeInfo}
     * @param _feeRecipient The address to receive the fee.
     * @param _feeNumerator The numerator of the fee fraction.
     */
    function setSalesFeeInfo(address _feeRecipient, uint256 _feeNumerator) public onlyOwner {
        _setSalesFeeInfo(_feeRecipient, _feeNumerator);
    }

    /**
     * @dev A function to withdraw the balance of the contract deriving from either sales fees accessed via
     * {AbstractFactory-salesFeeInfo},
     * or as flat fees for cloning defined in derived contracts, i.e. {PayableFactory-clone}.
     */
    function withdraw(address _fundsRecipient) external onlyOwner {
        payable(_fundsRecipient).sendValue(address(this).balance);
    }
}
