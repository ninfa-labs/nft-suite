// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./AbstractFactory.sol";
import "../access/Owned.sol";
import "../utils/Address.sol";

/**
 * @title OpenFactory
 * @notice Clone factory pattern contract without any access control or fee required in order to deploy a clone, as long
 * as it originates from a whitelisted master address.
 * @author cosimo.demedici.eth (https://github.com/ninfa-labs/ninfa-contracts)
 */
contract OpenFactory is AbstractFactory, Owned {
    using Address for address payable;

    /**
     * @notice The constructor sets the factory fee and calls the constructor of the parent contract.
     * @dev The constructor sets the contract's `owner` directly, because the Owned contract was modified to remove its
     * constructor (where `owner` is normally set).
     * @dev no multi-role access control was needed as the `clone` function is open to anyone in this derived contract
     * implementation.
     * @dev Fee information is set in the base {AbstractFactory-constructor}
     * @param _feeNumerator The numerator of the fee fraction.
     * @param _feeRecipient The address to receive the fee.
     */
    constructor(uint256 _feeNumerator, address _feeRecipient) AbstractFactory(_feeNumerator, _feeRecipient) {
        owner = msg.sender;
        // emit event fired by Owned contract when the owner is set
        emit OwnershipTransferred(address(0), msg.sender);
    }
    /**
     * @notice Clone function to create a new instance of a contract.
     * @param _instance The address of the instance to clone.
     * @param _salt A random number of our choice. Generated with
     * https://web3js.readthedocs.io/en/v1.2.11/web3-utils.html#randomhex
     * _salt could also be dynamically calculated in order to avoid duplicate
     * clones and for a way of finding predictable clones if salt the parameters are known.
     * @param _data The initialization data for the clone.
     * @return clone_ The address of the new clone.
     */

    function clone(address _instance, bytes32 _salt, bytes calldata _data) external returns (address clone_) {
        clone_ = _cloneDeterministic(_instance, _salt, _data);
    }

    function setMaster(address _instance, bool _isWhitelisted) external onlyOwner {
        _setMaster(_instance, _isWhitelisted);
    }

    /**
     * @dev see {AbstractFactory-salesFeeInfo}
     * @param _feeRecipient The address to receive the fee.
     * @param _feeNumerator The numerator of the fee fraction.
     */
    function setSalesFeeInfo(address _feeRecipient, uint256 _feeNumerator) external onlyOwner {
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
