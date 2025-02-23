// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./AbstractFactory.sol";
import "../access/AccessControl.sol";
import "../utils/Address.sol";

/**
 * @title CuratedFactory
 * @notice Clone factory pattern contract implementing role-based access control in order to deploy clone contracts,
 * i.e. only addresses given the custom `_MINTER_ROLE` can call the `clone` function (without any fees being charged),
 * as
 * long as the cloned contract originates from a whitelisted master address.
 * @author cosimo.demedici.eth (https://github.com/ninfa-labs/ninfa-contracts)
 */
contract CuratedFactory is AbstractFactory, AccessControl {
    using Address for address payable;

    /**
     * @dev The constructor sets role-based access control granting the factory deployer account both DEFAULT_ADMIN_ROLE
     * and the custom _CURATOR_ROLE.
     * @dev Fee information is set in the base {AbstractFactory-constructor}
     * @param _feeNumerator The numerator of the fee fraction.
     * @param _feeRecipient The address to receive the fee.
     */
    constructor(uint256 _feeNumerator, address _feeRecipient) AbstractFactory(_feeNumerator, _feeRecipient) {
        // grant the DEFAULT_ADMIN_ROLE to the contract deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // set the _CURATOR_ROLE as the admin of the _MINTER_ROLE
        _setRoleAdmin(_MINTER_ROLE, _CURATOR_ROLE);
        // grant the _CURATOR_ROLE to the contract deployer
        _grantRole(_CURATOR_ROLE, msg.sender);
    }

    /**
     * @dev keccak256("MINTER_ROLE");
     * @dev _MINTER_ROLE is needed for deploying new instances of the whitelisted collections,
     * it is equivalent to a whitelist of allowed deployers, it can be set by the _CURATOR_ROLE or made payable by
     * derived contracts
     */
    bytes32 internal constant _MINTER_ROLE = 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;
    /**
     * @dev keccak256("CURATOR_ROLE");
     * @dev _CURATOR_ROLE is needed particularly for the curated factory derived contract, in order for already
     * whitelisted minters (_MINTER_ROLE),
     * to be able to whitelist other minters, e.g. a gallery whitelisting artists, without having to pay in order to
     * whitelist them,
     * by using off-chain signatures and delegating the task to a backend service (using a _CURATOR_ROLE private key).
     * This minimizes security risks by not having to expose the admin private key to the backend service.
     */
    bytes32 internal constant _CURATOR_ROLE = 0x850d585eb7f024ccee5e68e55f2c26cc72e1e6ee456acf62135757a5eb9d4a10;

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
    function clone(
        address _instance,
        bytes32 _salt,
        bytes calldata _data
    )
        external
        onlyRole(_MINTER_ROLE)
        returns (address clone_)
    {
        clone_ = _cloneDeterministic(_instance, _salt, _data);
    }

    /**
     * @notice Whitelist or unwhitelist a master implementation.
     * @param _instance Address of the master implementation to whitelist.
     * @param _isWhitelisted Bool to set the implementation as whitelisted or not.
     */
    function setMaster(address _instance, bool _isWhitelisted) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMaster(_instance, _isWhitelisted);
    }

    /**
     * @dev see {AbstractFactory-salesFeeInfo}
     * @param _feeRecipient The address to receive the fee.
     * @param _feeNumerator The numerator of the fee fraction.
     */
    function setSalesFeeInfo(address _feeRecipient, uint256 _feeNumerator) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setSalesFeeInfo(_feeRecipient, _feeNumerator);
    }

    /**
     * @dev A function to withdraw the balance of the contract deriving from either sales fees accessed via
     * {AbstractFactory-salesFeeInfo},
     * or as flat fees for cloning defined in derived contracts, i.e. {PayableFactory-clone}.
     */
    function withdraw(address _fundsRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        payable(_fundsRecipient).sendValue(address(this).balance);
    }
}
