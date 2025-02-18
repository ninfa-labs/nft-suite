// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract EIP712 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  CONSTANTS AND IMMUTABLES                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    bytes32 private _DOMAIN_SEPARATOR;
    /// @dev `keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)")`.
    /// Assembly access to immutable variables is not supported (needed in order to compute _DOMAIN_SEPARATOR)
    /// string `version` is not included in the domain separator, because it is only needed for upgradable contracts
    bytes32 private constant _DOMAIN_TYPEHASH = 0x8cad95687ba82c2ce50e74f7b754645e5117c3a5bec8151c0726d5857980a866;

    mapping(address => mapping(bytes32 => bool)) internal _void;

    event VoidVouchers(address, bytes32[] digests);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  EIP-712 TYPED DATA SIGNING                */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev voidVouchers allows the owner of the voucher to void it, so it cannot be used anymore.
    /// MUST be used in case the signer raises the price, or cancels the voucher
    function voidVouchers(bytes32[] calldata _digests) external {
        uint256 i = _digests.length;
        do {
            --i;
            _void[msg.sender][_digests[i]] = true;
        } while (i > 0);
        emit VoidVouchers(msg.sender, _digests);
    }

    /// @dev Returns the hash of the fully encoded EIP-712 message for this domain,
    /// given `structHash`, as defined in
    /// https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct.
    ///
    /// The hash can be used together with {ECDSA-recover} to obtain the signer of a message:
    ///
    ///     bytes32 digest = _hashTypedData(keccak256(abi.encode(
    ///         keccak256("Mail(address to,string contents)"),
    ///         mailTo,
    ///         keccak256(bytes(mailContents))
    ///     )));
    ///     address signer = ECDSA.recover(digest, signature);
    ///
    function _hashTypedData(bytes32 structHash) internal view returns (bytes32 digest) {
        // We will use `digest` to store the domain separator to save a bit of gas.
        digest = _DOMAIN_SEPARATOR;
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the digest.
            // <----------------- 0x18 bytes ----------------->
            // 0000000000000000000000000000000000000000000000001901000000000000
            mstore(0x00, 0x1901000000000000) // Store "\x19\x01".
            mstore(0x1a, digest) // Store the domain separator.
            mstore(0x3a, structHash) // Store the struct hash.
            digest := keccak256(0x18, 0x42)
            // Restore the part of the free memory slot that was overwritten.
            mstore(0x3a, 0)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    EIP-5267 OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev See: https://eips.ethereum.org/EIPS/eip-5267. The event EIP712DomainChanged is not implemented as the
    /// domain is not expected to change.
    /// @param _fields a bit map where bit i is set to 1 if and only if domain field i is present (0 ≤ i ≤ 4). Bits
    /// are read from least significant to most significant, and fields are indexed in the order that is specified by
    /// EIP-712, identical to the order in which they are listed in the function type.
    /// @param _name, _version, _chainId, _verifyingContract: The value of the corresponding field in EIP712Domain
    function eip712Domain()
        external
        view
        returns (
            bytes1 _fields,
            string memory _name,
            string memory _version,
            uint256 _chainId,
            address _verifyingContract,
            bytes32 _salt,
            uint256[] memory _extensions
        )
    {
        /// @dev The binary representation 0b00001111 has the four least significant bits set to 1. This means the first
        /// four parameters of the domain are active or utilized. From the provided EIP-712 domain implementation, these
        /// parameters are: name, version, chainId, verifyingContract
        _fields = hex"0f";
        _name = name();
        _version = _version;
        _chainId = block.chainid;
        _verifyingContract = address(this);
        _salt = _salt; // `bytes32(0)`.
        _extensions = _extensions; // `new uint256[](0)`.
    }

    function name() public view virtual returns (string memory) { }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the EIP-712 domain separator.
    /// @dev this function is usful for contracts that need to change the domain separator,
    /// see https://github.com/Vectorized/solady/blob/main/src/utils/EIP712.sol for details
    function _buildDomainSeparator() private view returns (bytes32 separator) {
        bytes32 nameHash = keccak256(bytes(name())); // `_data` bytes must only contain the name string and nothing else
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Load the free memory pointer.
            mstore(m, _DOMAIN_TYPEHASH) // Store the DOMAIN_TYPEHASH at the beginning of the memory
            mstore(add(m, 0x20), nameHash) // Store the nameHash right after DOMAIN_TYPEHASH
            mstore(add(m, 0x40), chainid()) // Store the chainid() in the slot previously occupied by versionHash
            mstore(add(m, 0x60), address()) // Store the contract address right after chainid(), shifting everything up
                // by 0x20 due to the removal of versionHash
            separator := keccak256(m, 0x80) // Adjust the second argument of keccak256 to reflect the new size of the
                // data being hashed
        }
    }

    function initialize(bytes memory) public virtual {
        _DOMAIN_SEPARATOR = _buildDomainSeparator();
    }
}
