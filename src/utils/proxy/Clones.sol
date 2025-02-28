// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title Clones
 * @dev Implements the [EIP 1167](https://eips.ethereum.org/EIPS/eip-1167) standard for deploying minimal proxy
 * contracts, also known as "clones".
 * This standard provides a minimal bytecode implementation that delegates all calls to a known, fixed address, allowing
 * to clone contract functionality in an immutable way.
 * The library includes functions to deploy a proxy using either `create` (traditional deployment) or `create2` (salted
 * deterministic deployment). It also includes functions to predict the addresses of clones deployed using the
 * deterministic method.
 * @author cosimo.demedici.eth (https://github.com/ninfa-labs/nft-suite)
 * @author modified from OpenZeppelin Contracts v5.1.0 (access/AccessControl)
 */
library Clones {
    /**
     * @notice Deploys a clone that mimics the behaviour of `implementation` and returns its address.
     * @dev This function uses the create opcode, which should never revert.
     * @param implementation The address of the contract to clone.
     * @return instance The address of the deployed clone.
     */
    function clone(address implementation) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create(0, 0x09, 0x37)
        }
        require(instance != address(0), "ERC1167: create failed");
    }

    /**
     * @notice Deploys a clone that mimics the behaviour of `implementation` and returns its address.
     * @dev This function uses the create2 opcode and a `salt` to deterministically deploy the clone. Using the same
     * `implementation` and `salt` multiple times will revert, since the clones cannot be deployed twice at the same
     * address.
     * @param implementation The address of the contract to clone.
     * @param salt The salt for deterministic deployment.
     * @return instance The address of the deployed clone.
     */
    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create2(0, 0x09, 0x37, salt)
        }
        require(instance != address(0), "ERC1167: create2 failed");
    }

    /**
     * @notice Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     * @param implementation The address of the contract to clone.
     * @param salt The salt for deterministic deployment.
     * @param deployer The address of the deployer.
     * @return predicted The predicted address of the deployed clone.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    )
        internal
        pure
        returns (address predicted)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x38), deployer)
            mstore(add(ptr, 0x24), 0x5af43d82803e903d91602b57fd5bf3ff)
            mstore(add(ptr, 0x14), implementation)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
            mstore(add(ptr, 0x58), salt)
            mstore(add(ptr, 0x78), keccak256(add(ptr, 0x0c), 0x37))
            predicted := keccak256(add(ptr, 0x43), 0x55)
        }
    }

    /**
     * @notice Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     * @param implementation The address of the contract to clone.
     * @param salt The salt for deterministic deployment.
     * @return predicted The predicted address of the deployed clone.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt
    )
        internal
        view
        returns (address predicted)
    {
        return predictDeterministicAddress(implementation, salt, address(this));
    }
}
