// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

/**
 * @notice Simple single owner authorization mixin.
 * @dev Returns `true` if `account` has been granted `role`.
 * @dev constructor was removed from original implementation, because contracts that need to be deployed from factory,
 * or any upgradeable contract, should not have a constructor and therefore owner should be set in the initializer,
 * this is done atomically when deploying a clone from a factory.
 * @author cosimo.demedici.eth (https://github.com/ninfa-labs/ninfa-contracts)
 * @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
 */
abstract contract Owned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(address indexed user, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "UNAUTHORIZED");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
    }
}
