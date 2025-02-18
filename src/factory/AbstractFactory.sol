// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../utils/proxy/Clones.sol";
import "../access/Owned.sol";

/**
 * @title AbstractFactory
 * @notice Abstract implementation for clone factory contracts
 * @author cosimo.demedici.eth (https://github.com/ninfa-labs/ninfa-contracts)
 */
abstract contract AbstractFactory {
    using Clones for address;

    uint256 private constant _TOTAL_BPS = 10_000;

    /**
     * @dev fee recipient for sales
     */
    address private _salesFeeRecipient;

    /**
     * @dev fee fraction for sales fee calculation (e.g. 1000 = 10%)
     */
    uint256 private _salesFeeBps;

    /**
     * @notice whitelisted implementations' addresses; i.e. allowlist of clonable contracts
     */
    mapping(address => bool) private _mastersWhitelist;
    /**
     * @notice cloned instances' addresses, needed by external contracts for access control
     */
    mapping(address => bool) private _clonesDeployed;

    /**
     * @dev Event emitted when a new clone is created.
     * @param master The address of the master implementation.
     * @param instance The address of the new clone.
     * @param owner is needed in order to keep a local database of owners to instance addresses; this avoids keeping
     * track of them on-chain via a mapping.
     */
    event NewClone(address master, address instance, address owner);

    /**
     * @dev Event emitted when a master implementation is updated.
     * @param master The address of the master implementation.
     * @param isWhitelisted Bool to set the implementation as whitelisted or not.
     */
    event MastersWhitelistUpdated(address master, bool isWhitelisted);

    /**
     * @dev Event emitted when the sales fee information is updated.
     * @param feeRecipient The address to receive the fee.
     * @param salesFeeBps The numerator of the fee fraction.
     */
    event SalesFeeInfoUpdated(address feeRecipient, uint256 salesFeeBps);

    /**
     * @dev The constructor sets the sales fee information.
     * @dev ownership information must be set in derived contracts.
     * @param salesFeeBps_ The numerator of the fee fraction.
     * @param salesFeeRecipient_ The address to receive the fee.
     */
    constructor(uint256 salesFeeBps_, address salesFeeRecipient_) {
        _setSalesFeeInfo(salesFeeRecipient_, salesFeeBps_);
    }

    /**
     * @dev sets contract-wide fee information defined as a percentage (of the sale price),
     * in order for self-sovereign contracts to be able to pay a fee to the factory if needed,
     * this allows clones to fetch up to date fee information rather than hardcoding it.
     * e.g. see {ERC1155OpenEdition-mint}, here is an extract:
     * ```
     *     (bool success, bytes memory returnData) =
     *         FACTORY.call(abi.encodeWithSignature("salesFeeInfo(uint256)", msg.value));
     *     require(success);
     *     (address feeRecipient, uint256 feeAmount) = abi.decode(returnData, (address, uint256));
     *     feeRecipient.sendValue(feeAmount);
     * ```
     * @param _salePrice The price of the sale.
     */
    function salesFeeInfo(uint256 _salePrice) external view returns (address, uint256) {
        uint256 feeAmount = (_salePrice * _salesFeeBps) / _TOTAL_BPS;

        return (_salesFeeRecipient, feeAmount);
    }

    /**
     * @notice Checks if a contract instance exists.
     * @dev This function may be used by other contracts for access control,
     * i.e. a marketplace like contract using this factory as a source of truth for whitelisted collections.
     * @param _clone Address of the instance to check.
     * @return A boolean indicating if the instance exists.
     */
    function exists(address _clone) external view returns (bool) {
        return _clonesDeployed[_clone];
    }

    /**
     * @notice Predicts the deterministic address for a given implementation and salt.
     * @param _master The address of the master implementation.
     * @param _salt The salt to use for prediction.
     * @return The predicted address.
     */
    function predictDeterministicAddress(address _master, bytes32 _salt) external view returns (address) {
        return _master.predictDeterministicAddress(_salt);
    }

    /**
     * @notice Clone function to create a new instance of a contract.
     * @dev "Using the same implementation and salt multiple time will revert,
     * since the clones cannot be cloneed twice
     * at the same address." -
     * https://docs.openzeppelin.com/contracts/4.x/api/proxy#Clones-cloneDeterministic-address-bytes32-
     * @dev Initializes clones upon deployment via a low-level call (more gas-efficient) to invoke the `initialize`
     * function atomically,
     * because a `constructor` cannot be used while deploying proxy contracts such as clones.
     * @param _salt _salt is a random number of our choice. generated with
     * https://web3js.readthedocs.io/en/v1.2.11/web3-utils.html#randomhex
     * _salt could also be dynamically calculated in order to avoid duplicate
     * clones and for a way of finding
     * predictable clones if salt the parameters are known, for example:
     * `address _clone =
     * erc1155Minter.cloneDeterministic(†bytes32(keccak256(abi.encode(_name,
     * _symbol,
     * _msgSender))));`
     * @param _master MUST be one of this factory's whhitelisted collections
     * @param _data The initialization data for the clone. It is the calldata that will be passed to the clone's
     * initialize function.
     */
    function _cloneDeterministic(
        address _master,
        bytes32 _salt,
        bytes calldata _data
    )
        internal
        returns (address clone_)
    {
        require(_mastersWhitelist[_master]);

        clone_ = _master.cloneDeterministic(_salt);
        /// The function selector is calculated as `bytes4(keccak256('initialize(bytes)')) == 0x439fab91`
        (bool success,) = clone_.call(abi.encodeWithSelector(0x439fab91, _data));
        require(success);

        _clonesDeployed[clone_] = true;

        emit NewClone(_master, clone_, msg.sender);
    }

    /**
     * @notice Whitelist or unwhitelist a master implementation.
     * @dev External visibility because it is meant to be needed by all derived contracts,
     * i.e. no point in having a public getter for it, to avoid extra code.
     * @param _master Address of the master implementation to whitelist.
     * @param _isWhitelisted Bool to set the implementation as whitelisted or not.
     */
    function _setMaster(address _master, bool _isWhitelisted) internal {
        // safety check, expects the master to be deployed before it can be whitelisted
        require(_master.code.length > 0);

        _mastersWhitelist[_master] = _isWhitelisted;

        emit MastersWhitelistUpdated(_master, _isWhitelisted);
    }

    /**
     * @dev see {AbstractFactory-salesFeeInfo}
     * @param salesFeeRecipient_ The address to receive the fee.
     * @param salesFeeBps_ The numerator of the fee fraction.
     */
    function _setSalesFeeInfo(address salesFeeRecipient_, uint256 salesFeeBps_) internal {
        require(salesFeeBps_ < _TOTAL_BPS, "sale fee will exceed salePrice");
        require(salesFeeRecipient_ != address(0), "invalid fee receiver");

        _salesFeeRecipient = salesFeeRecipient_;
        _salesFeeBps = salesFeeBps_;

        emit SalesFeeInfoUpdated(salesFeeRecipient_, salesFeeBps_);
    }
}
