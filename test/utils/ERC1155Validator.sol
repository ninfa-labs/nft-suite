// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import {
    ERC1155Recipient,
    RevertingERC1155Recipient,
    WrongReturnDataERC1155Recipient,
    NonERC1155Recipient
} from "test/utils/mocks/ERC1155Recipient.sol";
import "test/interfaces/IERC165.sol";
import "test/interfaces/IERC1155.sol";
import "test/interfaces/IERC1155Metadata_URI.sol";
import "test/interfaces/IERC1155Supply.sol";
import "test/interfaces/IERC1155Mintable.sol";
import "test/interfaces/IERC1155LazyMintable.sol";
import "test/interfaces/IERC1155Burnable.sol";
import "test/interfaces/IERC721LazyMint.sol";
import "test/interfaces/IEIP712Domain.sol";

abstract contract ERC1155Validator is Test {
    /// @dev `keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)")`.
    /// Assembly access to immutable variables is not supported (needed in order to compute _DOMAIN_SEPARATOR)
    /// string `version` is not included in the domain separator, because it is only needed for upgradable contracts
    bytes32 private constant _DOMAIN_TYPEHASH = 0x8cad95687ba82c2ce50e74f7b754645e5117c3a5bec8151c0726d5857980a866;
    /// @dev `keccak256("EncodeType.TokenVoucher(bytes32 tokenURI,uint256 price,uint256 endTime,uint256 tokenId,uint256
    /// ERC1155Value,uint256 salt,address buyer,address ERC1271Account,address royaltyRecipient,uint96
    /// royaltyBps,uint96[] commissionBps,address[] commissionRecipients)");`
    bytes32 private constant _VOUCHER_TYPEHASH = 0x42496782cf3e7555d82117811afa0bdaee1320050e381001920fcb0da51bd83e;

    function ERC1155Value() internal view virtual returns (uint256) { }

    /*----------------------------------------------------------*|
    |*  # CUSTOM TESTS                                          *|
    |*----------------------------------------------------------*/

    function _testSupportsInterface(address _ERC1155) internal view {
        assertEq(IERC165(_ERC1155).supportsInterface(0xd9b67a26 /*type(IERC1155).interfaceId*/ ), true);
        assertEq(IERC165(_ERC1155).supportsInterface(0x01ffc9a7 /*type(IERC165).interfaceId*/ ), true);
        assertEq(IERC165(_ERC1155).supportsInterface(0x2a55205a), true); // Interface ID for IERC2981
        assertEq(IERC165(_ERC1155).supportsInterface(0x0e89341c), true); // Interface ID for IERC1155MetadataURI
        assertEq(IERC165(_ERC1155).supportsInterface(0x7965db0b), true); // Interface ID for IAccessControl
    }

    function _testERC1155Metadata(address _ERC1155) internal view {
        assertEq(IERC165(_ERC1155).supportsInterface(type(IERC1155Metadata_URI).interfaceId), true);

        string memory tokenURI = IERC1155Metadata_URI(_ERC1155).uri(0);
        assertEq(bytes(tokenURI).length > 0, true);
    }

    function _testERC1155Enumerable(address _ERC1155) internal view {
        assertEq(IERC1155Supply(_ERC1155).exists(0), true);
        assertEq(IERC1155Supply(_ERC1155).totalSupply(0), 1);
        assertEq(IERC1155Supply(_ERC1155).totalSupply(), 1);
    }

    /*----------------------------------------------------------*|
    |*  # EIP-5267                                              *|
    |*----------------------------------------------------------*/

    /// @dev example to build domain sepaeator from external contract call, or as an example for frontends
    function _buildDomainSeparator(address contractAddress) private view returns (bytes32 separator) {
        string memory name;
        uint256 chainId;
        address verifyingContract;

        (
            /*bytes1 fields*/
            ,
            name,
            /*string memory version*/
            ,
            chainId,
            verifyingContract,
            /*bytes32 salt*/
            ,
            /*uint256[] memory extensions*/
        ) = IEIP712Domain(contractAddress).eip712Domain();

        bytes32 nameHash = keccak256(bytes(name)); // `_data` bytes must only contain the name string and nothing else

        // Assuming extensions are not used in the domain type hash
        // Not including `fields` and `extensions` directly if they're not part of the hash
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Load the free memory pointer.
            mstore(m, _DOMAIN_TYPEHASH) // Store the DOMAIN_TYPEHASH at the beginning of the memory
            mstore(add(m, 0x20), nameHash) // Store the nameHash right after DOMAIN_TYPEHASH
            mstore(add(m, 0x40), chainid()) // Store the chainid() in the slot previously occupied by versionHash
            mstore(add(m, 0x60), contractAddress) // Store the contract address right after chainid(), shifting
                // everything up
                // by 0x20 due to the removal of versionHash
            separator := keccak256(m, 0x80) // Adjust the second argument of keccak256 to reflect the new size of the
                // data being hashed
        }
    }

    function _testEIP712Domain(address _ERC1155) internal view {
        /*bytes32 domainSeparator = */
        _buildDomainSeparator(_ERC1155);
        /// @dev there is no way to assert that `domainSeparator` is correct within this test as the domain separator in
        /// the contract is private
        /// however any test using EIP-5267 i.e. eip712Domain() for signature EIP-712 verification should be able to
        /// verify the domain separator is correct implicitly
    }

    /*----------------------------------------------------------*|
    |*  # EIP-712                                         *|
    |*----------------------------------------------------------*/

    function _getDigestAndSignature(
        address _collection,
        EncodeType.TokenVoucher memory _voucher,
        uint256 _PK
    )
        private
        view
        returns (bytes32 digest, bytes memory signature)
    {
        digest = IERC721LazyMint(_collection).getTypedDataDigest(_voucher);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_PK, digest);
        signature = abi.encodePacked(r, s, v);
        // address signer = ecrecover(digest, v, r, s);
    }

    function _testLazyMint(
        address _ERC1155,
        uint256 _PK,
        uint256 _unitPrice,
        uint256 _tokenId,
        uint96 _royaltyBps,
        uint96[] memory _commissionBps,
        address _collector,
        address _royaltyRecipient,
        address[] memory _commissionRecipients
    )
        internal
    {
        // uint256 tokenId = IERC1155Supply(_ERC1155).totalSupply(); // call before minting
        uint256 value = ERC1155Value(); // call before minting
        uint256 collectorBalance = IERC1155(_ERC1155).balanceOf(_collector, _tokenId); // call before minting
        EncodeType.TokenVoucher memory voucher = EncodeType.TokenVoucher(
            bytes32("foobar"), // tokenURI
            _unitPrice, // price
            type(uint32).max, // endTime
            _tokenId, // tokenid
            100, // ERC1155Value
            block.timestamp, // salt
            address(0), // whitelisted buyer
            address(0), // ERC1271Account
            _royaltyRecipient,
            _royaltyBps,
            _commissionBps,
            _commissionRecipients
        );

        ( /*bytes32 digest*/ , bytes memory signature) = _getDigestAndSignature(_ERC1155, voucher, _PK);

        vm.prank(_collector);
        IERC1155LazyMintable(_ERC1155).lazyMint{ value: _unitPrice * value }(
            voucher, signature, "testing 123", _collector, value, _tokenId
        );

        assertEq(IERC1155(_ERC1155).balanceOf(_collector, _tokenId), collectorBalance + value, "EOA balance incorrect");

        // if collector is a contract
        if (_collector.code.length > 0) {
            assertEq(ERC1155Recipient(_collector).operator(), address(this), "wrong operator");
            assertEq(ERC1155Recipient(_collector).from(), _royaltyRecipient, "wrong royalty recipient");
            assertEq(ERC1155Recipient(_collector).id(), _tokenId, "wrong token Id");
            assertEq(ERC1155Recipient(_collector).mintData(), "testing 123", "wrong mint data");
        }
    }

    // function _testLazyMintFromEOAtoERC1155Recipient(
    //     address _ERC1155,
    //     uint256 _PK,
    //     uint256 _unitPrice,
    //     uint96 _royaltyBps,
    //     uint96[] memory _commissionBps,
    //     address _royaltyRecipient,
    //     address[] memory _commissionRecipients
    // )
    //     internal
    // {

    //     vm.deal(address(to), 100 ether);

    //     uint256 tokenId = IERC1155Supply(_ERC1155).totalSupply(); // call before minting
    //     uint256 collectorBalance = IERC1155(_ERC1155).balanceOf(address(to), tokenId); // call before minting

    //     EncodeType.TokenVoucher memory voucher = EncodeType.TokenVoucher(
    //         bytes32("foobar"), // tokenURI
    //         _unitPrice, // price
    //         type(uint32).max, // endTime
    //         tokenId, // tokenid
    //         0, // ERC1155Value
    //         block.timestamp, // salt
    //         address(0), // whitelisted buyer
    //         address(0), // ERC1271Account
    //         _royaltyRecipient,
    //         _royaltyBps,
    //         _commissionBps,
    //         _commissionRecipients
    //     );

    //     (/*bytes32 digest*/, bytes memory signature) = _getDigestAndSignature(_ERC1155, voucher, _PK);

    //     vm.prank(address(to));
    //     IERC1155LazyMintable(_ERC1155).lazyMint{value: _unitPrice}(voucher, signature, "testing 123", address(to),
    // 1);

    //     assertEq(IERC1155(_ERC1155).balanceOf(address(to), tokenId), collectorBalance + 1, "EOA balance incorrect");

    //     assertEq(to.operator(), address(to), "wrong operator");
    //     assertEq(to.from(), _royaltyRecipient, "wrong royalty recipient"); // todo shouldnt this be address 0?
    //     assertEq(to.id(), tokenId, "wrong token Id");
    //     assertEq(to.mintData(), "testing 123", "wrong mint data");
    // }

    /*----------------------------------------------------------*|
    |*  # SOLMATE TESTS                                         *|
    |*----------------------------------------------------------*/

    /// @dev name and symbol are not part of the standard technically
    /// @dev name and symbol are optional, pass "" if name and symbol are not known
    function _invariantERC1155Metadata(address _ERC1155, string memory _name, string memory _symbol) internal view {
        if (bytes(_name).length > 0) {
            assertEq(IERC721LazyMint(_ERC1155).name(), _name, "wrong name");
        } else {
            _name = IERC721LazyMint(_ERC1155).name();
            assertEq(bytes(_name).length > 0, true, "no name");
        }

        if (bytes(_symbol).length > 0) {
            assertEq(IERC721LazyMint(_ERC1155).symbol(), _symbol, "wrong symbol");
        } else {
            _symbol = IERC721LazyMint(_ERC1155).symbol();
            assertEq(bytes(_symbol).length > 0, true, "no symbol");
        }
    }

    // todo test lazy mint from ERC1271Account

    function _testMintToEOA(address _ERC1155) internal view {
        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 0), 1);
    }

    function _testMintToERC1155Recipient(address _ERC1155, uint96 _royaltyBps, address _royaltyRecipient) internal {
        ERC1155Recipient to = new ERC1155Recipient();

        IERC1155Mintable(_ERC1155).mint(
            address(to), 1, abi.encode(bytes32("foobar"), abi.encode(_royaltyRecipient, _royaltyBps, "test 123"))
        );

        assertEq(IERC1155(_ERC1155).balanceOf(address(to), 1), 1, "wrong recipient balance");

        assertEq(to.operator(), address(this), "wrong operator");
        assertEq(to.from(), address(0), "wrong from");
        assertEq(to.id(), 1, "wrong token Id");
        // assertEq(to.mintData(), "test 123", "wrong mint data"); // TODO FAILING! FIX
    }

    function _testMintBatchToEOA(address _ERC1155) internal {
        uint256[] memory amounts_ = new uint256[](5);
        amounts_[0] = 100;
        amounts_[1] = 200;
        amounts_[2] = 300;
        amounts_[3] = 400;
        amounts_[4] = 500;

        IERC1155Mintable(_ERC1155).mintBatch(address(this), amounts_, abi.encodePacked("foobar"));

        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 1), 100);
        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 2), 200);
        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 3), 300);
        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 4), 400);
        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 5), 500);
    }

    function _testMintBatchToERC1155Recipient(address _ERC1155) internal {
        ERC1155Recipient to = new ERC1155Recipient();

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;

        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;
        amounts[3] = 400;
        amounts[4] = 500;

        IERC1155Mintable(_ERC1155).mintBatch(address(to), amounts, "testing 123");

        assertEq(to.batchOperator(), address(this));
        assertEq(to.batchFrom(), address(0));
        assertEq(to.batchIds(), ids); // TODO
        assertEq(to.batchAmounts(), amounts); // TODO
        assertEq(to.batchData(), "testing 123");

        assertEq(IERC1155(_ERC1155).balanceOf(address(to), 1), 100);
        assertEq(IERC1155(_ERC1155).balanceOf(address(to), 2), 200);
        assertEq(IERC1155(_ERC1155).balanceOf(address(to), 3), 300);
        assertEq(IERC1155(_ERC1155).balanceOf(address(to), 4), 400);
        assertEq(IERC1155(_ERC1155).balanceOf(address(to), 5), 500);
    }

    function _testBurn(address _ERC1155) internal {
        assertEq(IERC1155Supply(_ERC1155).exists(0), true, "token does not exist");
        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 0), 1, "wrong balance");
        assertEq(IERC1155Supply(_ERC1155).totalSupply(0), 1, "wrong supply");

        IERC1155Burnable(_ERC1155).burn(address(this), 0, 1);

        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 0), 0, "wrong balance");
        assertEq(IERC1155Supply(_ERC1155).totalSupply(0), 0, "wrong supply");
    }

    function _testBurnBatch(address _ERC1155) internal {
        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        uint256[] memory burnAmounts = new uint256[](5);
        burnAmounts[0] = 50;
        burnAmounts[1] = 100;
        burnAmounts[2] = 150;
        burnAmounts[3] = 200;
        burnAmounts[4] = 250;

        IERC1155Mintable(_ERC1155).mintBatch(address(this), mintAmounts, "");

        IERC1155Burnable(_ERC1155).burnBatch(address(this), ids, burnAmounts);

        assertEq(IERC1155(_ERC1155).balanceOf(address(this), ids[0]), mintAmounts[0] - burnAmounts[0]);
        assertEq(IERC1155(_ERC1155).balanceOf(address(this), ids[1]), mintAmounts[1] - burnAmounts[1]);
        assertEq(IERC1155(_ERC1155).balanceOf(address(this), ids[2]), mintAmounts[2] - burnAmounts[2]);
        assertEq(IERC1155(_ERC1155).balanceOf(address(this), ids[3]), mintAmounts[3] - burnAmounts[3]);
        assertEq(IERC1155(_ERC1155).balanceOf(address(this), ids[4]), mintAmounts[4] - burnAmounts[4]);
    }

    function _testApproveAll(address _ERC1155) internal {
        IERC1155(_ERC1155).setApprovalForAll(address(0xABCD), true);

        assertTrue(IERC1155(_ERC1155).isApprovedForAll(address(this), address(0xABCD)));
    }

    function _testSafeTransferFromToEOA(address _ERC1155) internal {
        address sender = address(0xABCD);

        IERC1155(_ERC1155).setApprovalForAll(sender, true);

        vm.prank(sender);
        IERC1155(_ERC1155).safeTransferFrom(address(this), sender, 0, 1, "");

        assertEq(IERC1155(_ERC1155).balanceOf(sender, 0), 1);
        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 0), 0);
    }

    function _testSafeTransferFromToERC1155Recipient(address _ERC1155) internal {
        ERC1155Recipient to = new ERC1155Recipient();

        IERC1155(_ERC1155).setApprovalForAll(address(0xABCD), true);

        vm.prank(address(0xABCD));
        IERC1155(_ERC1155).safeTransferFrom(address(this), address(to), 0, 1, "testing 123");

        assertEq(to.operator(), address(0xABCD));
        assertEq(to.from(), address(this));
        assertEq(to.id(), 0);
        assertEq(to.mintData(), "testing 123");

        assertEq(IERC1155(_ERC1155).balanceOf(address(to), 0), 1);
        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 0), 0);
    }

    function _testSafeTransferFromSelf(address _ERC1155) internal {
        IERC1155(_ERC1155).safeTransferFrom(address(this), address(0xBEEF), 0, 1, "");

        assertEq(IERC1155(_ERC1155).balanceOf(address(0xBEEF), 0), 1);
        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 0), 0);
    }

    function _testSafeBatchTransferFromToEOA(address _ERC1155) internal {
        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 50;
        transferAmounts[1] = 100;
        transferAmounts[2] = 150;
        transferAmounts[3] = 200;
        transferAmounts[4] = 250;

        // IERC1155Mintable(_ERC1155).mintBatch(address(this), mintAmounts, "");

        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[0], abi.encode(keccak256("FOOBAR1"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[1], abi.encode(keccak256("FOOBAR2"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[2], abi.encode(keccak256("FOOBAR3"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[3], abi.encode(keccak256("FOOBAR4"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[4], abi.encode(keccak256("FOOBAR5"), abi.encode(address(0), 0, ""))
        );

        IERC1155(_ERC1155).safeBatchTransferFrom(address(this), address(0xBEEF), ids, transferAmounts, "");

        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 1), 50);
        assertEq(IERC1155(_ERC1155).balanceOf(address(0xBEEF), 1), 50);

        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 2), 100);
        assertEq(IERC1155(_ERC1155).balanceOf(address(0xBEEF), 2), 100);

        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 3), 150);
        assertEq(IERC1155(_ERC1155).balanceOf(address(0xBEEF), 3), 150);

        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 4), 200);
        assertEq(IERC1155(_ERC1155).balanceOf(address(0xBEEF), 4), 200);

        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 5), 250);
        assertEq(IERC1155(_ERC1155).balanceOf(address(0xBEEF), 5), 250);
    }

    function _testSafeBatchTransferFromToERC1155Recipient(address _ERC1155) internal {
        ERC1155Recipient to = new ERC1155Recipient();

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 50;
        transferAmounts[1] = 100;
        transferAmounts[2] = 150;
        transferAmounts[3] = 200;
        transferAmounts[4] = 250;

        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[0], abi.encode(keccak256("FOOBAR1"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[1], abi.encode(keccak256("FOOBAR2"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[2], abi.encode(keccak256("FOOBAR3"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[3], abi.encode(keccak256("FOOBAR4"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[4], abi.encode(keccak256("FOOBAR5"), abi.encode(address(0), 0, ""))
        );

        IERC1155(_ERC1155).setApprovalForAll(address(0xABCD), true);

        vm.prank(address(0xABCD));
        IERC1155(_ERC1155).safeBatchTransferFrom(address(this), address(to), ids, transferAmounts, "testing 123");

        assertEq(to.batchOperator(), address(0xABCD));
        assertEq(to.batchFrom(), address(this));
        assertEq(to.batchIds(), ids);
        assertEq(to.batchAmounts(), transferAmounts);
        assertEq(to.batchData(), "testing 123");

        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 1), 50);
        assertEq(IERC1155(_ERC1155).balanceOf(address(to), 1), 50);

        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 2), 100);
        assertEq(IERC1155(_ERC1155).balanceOf(address(to), 2), 100);

        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 3), 150);
        assertEq(IERC1155(_ERC1155).balanceOf(address(to), 3), 150);

        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 4), 200);
        assertEq(IERC1155(_ERC1155).balanceOf(address(to), 4), 200);

        assertEq(IERC1155(_ERC1155).balanceOf(address(this), 5), 250);
        assertEq(IERC1155(_ERC1155).balanceOf(address(to), 5), 250);
    }

    function _testBatchBalanceOf(address _ERC1155) internal {
        address[] memory tos = new address[](5);
        tos[0] = address(0xBEEF);
        tos[1] = address(0xCAFE);
        tos[2] = address(0xFACE);
        tos[3] = address(0xDEAD);
        tos[4] = address(0xFEED);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        IERC1155Mintable(_ERC1155).mint(
            address(0xBEEF), mintAmounts[0], abi.encode(keccak256("FOOBAR1"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(0xCAFE), mintAmounts[1], abi.encode(keccak256("FOOBAR2"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(0xFACE), mintAmounts[2], abi.encode(keccak256("FOOBAR3"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(0xDEAD), mintAmounts[3], abi.encode(keccak256("FOOBAR4"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(0xFEED), mintAmounts[4], abi.encode(keccak256("FOOBAR5"), abi.encode(address(0), 0, ""))
        );

        uint256[] memory balances = IERC1155(_ERC1155).balanceOfBatch(tos, ids);

        assertEq(balances[0], mintAmounts[0]);
        assertEq(balances[1], mintAmounts[1]);
        assertEq(balances[2], mintAmounts[2]);
        assertEq(balances[3], mintAmounts[3]);
        assertEq(balances[4], mintAmounts[4]);
    }

    function _testFailMintToZero(address _ERC1155) internal {
        vm.expectRevert();
        IERC1155Mintable(_ERC1155).mint(address(0), 100, abi.encode(keccak256("FOOBAR"), abi.encode(address(0), 0, "")));
    }

    function _testFailMintToNonERC1155Recipient(address _ERC1155) internal {
        address nonERC1155Recipient = address(new NonERC1155Recipient());
        vm.expectRevert();
        IERC1155Mintable(_ERC1155).mint(
            nonERC1155Recipient, 1, abi.encode(keccak256("FOOBAR"), abi.encode(address(0), 0, ""))
        );
    }

    function _testFailMintToRevertingERC1155Recipient(address _ERC1155) internal {
        address revertingERC1155Recipient = address(new RevertingERC1155Recipient());
        vm.expectRevert();
        IERC1155Mintable(_ERC1155).mint(
            revertingERC1155Recipient, 1, abi.encode(keccak256("FOOBAR"), abi.encode(address(0), 0, ""))
        );
    }

    function _testFailMintToWrongReturnDataERC1155Recipient(address _ERC1155) internal {
        address wrongReturnDataERC1155Recipient = address(new WrongReturnDataERC1155Recipient());
        vm.expectRevert();
        IERC1155Mintable(_ERC1155).mint(
            wrongReturnDataERC1155Recipient, 1, abi.encode(keccak256("FOOBAR"), abi.encode(address(0), 0, ""))
        );
    }

    function _testFailBurnInsufficientBalance(address _ERC1155) internal {
        IERC1155Burnable(_ERC1155).burn(address(this), 0, 100);
    }

    function _testFailSafeTransferFromInsufficientBalance(address _ERC1155) internal {
        IERC1155(_ERC1155).setApprovalForAll(address(0xABCD), true);

        vm.expectRevert();
        vm.prank(address(0xABCD));
        IERC1155(_ERC1155).safeTransferFrom(address(this), address(0xBEEF), 0, 100, "");
    }

    function _testFailSafeTransferFromSelfInsufficientBalance(address _ERC1155) internal {
        vm.expectRevert();
        IERC1155(_ERC1155).safeTransferFrom(address(this), address(0xBEEF), 0, 100, "");
    }

    function _testFailSafeTransferFromToZero(address _ERC1155) internal {
        vm.expectRevert();
        IERC1155(_ERC1155).safeTransferFrom(address(this), address(0), 0, 1, "");
    }

    function _testFailSafeTransferFromToNonERC1155Recipient(address _ERC1155) internal {
        address nonERC1155Recipient = address(new NonERC1155Recipient());
        vm.expectRevert();
        IERC1155(_ERC1155).safeTransferFrom(address(this), nonERC1155Recipient, 0, 70, "");
    }

    function _testFailSafeTransferFromToRevertingERC1155Recipient(address _ERC1155) internal {
        address revertingERC1155Recipient = address(new RevertingERC1155Recipient());
        vm.expectRevert();
        IERC1155(_ERC1155).safeTransferFrom(address(this), revertingERC1155Recipient, 0, 70, "");
    }

    function _testFailSafeTransferFromToWrongReturnDataERC1155Recipient(address _ERC1155) internal {
        address wrongReturnDataERC1155Recipient = address(new WrongReturnDataERC1155Recipient());
        vm.expectRevert();
        IERC1155(_ERC1155).safeTransferFrom(address(this), wrongReturnDataERC1155Recipient, 0, 70, "");
    }

    function _testFailSafeBatchTransferInsufficientBalance(address _ERC1155) internal {
        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;

        uint256[] memory mintAmounts = new uint256[](5);

        mintAmounts[0] = 50;
        mintAmounts[1] = 100;
        mintAmounts[2] = 150;
        mintAmounts[3] = 200;
        mintAmounts[4] = 250;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 100;
        transferAmounts[1] = 200;
        transferAmounts[2] = 300;
        transferAmounts[3] = 400;
        transferAmounts[4] = 500;

        // IERC1155Mintable(_ERC1155).batchMint(address(this), ids, mintAmounts, "");

        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[0], abi.encode(keccak256("FOOBAR1"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[1], abi.encode(keccak256("FOOBAR2"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[2], abi.encode(keccak256("FOOBAR3"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[3], abi.encode(keccak256("FOOBAR4"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[4], abi.encode(keccak256("FOOBAR5"), abi.encode(address(0), 0, ""))
        );

        IERC1155(_ERC1155).setApprovalForAll(address(0xABCD), true);

        vm.expectRevert();
        vm.prank(address(0xABCD));
        IERC1155(_ERC1155).safeBatchTransferFrom(address(this), address(0xBEEF), ids, transferAmounts, "");
    }

    function _testFailSafeBatchTransferFromToZero(address _ERC1155) internal {
        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 50;
        transferAmounts[1] = 100;
        transferAmounts[2] = 150;
        transferAmounts[3] = 200;
        transferAmounts[4] = 250;

        // // IERC1155(_ERC1155).batchMint(from, ids, mintAmounts, "");

        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[0], abi.encode(keccak256("FOOBAR1"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[1], abi.encode(keccak256("FOOBAR2"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[2], abi.encode(keccak256("FOOBAR3"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[3], abi.encode(keccak256("FOOBAR4"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[4], abi.encode(keccak256("FOOBAR5"), abi.encode(address(0), 0, ""))
        );

        IERC1155(_ERC1155).setApprovalForAll(address(0xABCD), true);

        vm.expectRevert();
        vm.prank(address(0xABCD));
        IERC1155(_ERC1155).safeBatchTransferFrom(address(0xABCD), address(0), ids, transferAmounts, "");
    }

    function _testFailSafeBatchTransferFromToNonERC1155Recipient(address _ERC1155) internal {
        address operator = address(0xABCD);
        address nonERC1155Recipient = address(new NonERC1155Recipient());

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 50;
        transferAmounts[1] = 100;
        transferAmounts[2] = 150;
        transferAmounts[3] = 200;
        transferAmounts[4] = 250;

        // // IERC1155(_ERC1155).batchMint(from, ids, mintAmounts, "");

        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[0], abi.encode(keccak256("FOOBAR1"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[1], abi.encode(keccak256("FOOBAR2"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[2], abi.encode(keccak256("FOOBAR3"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[3], abi.encode(keccak256("FOOBAR4"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[4], abi.encode(keccak256("FOOBAR5"), abi.encode(address(0), 0, ""))
        );

        IERC1155(_ERC1155).setApprovalForAll(operator, true);

        vm.expectRevert();
        vm.prank(operator);
        IERC1155(_ERC1155).safeBatchTransferFrom(address(this), nonERC1155Recipient, ids, transferAmounts, "");
    }

    function _testFailSafeBatchTransferFromToRevertingERC1155Recipient(address _ERC1155) internal {
        address operator = address(0xABCD);
        address revertingERC1155Recipient = address(new RevertingERC1155Recipient());

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 50;
        transferAmounts[1] = 100;
        transferAmounts[2] = 150;
        transferAmounts[3] = 200;
        transferAmounts[4] = 250;

        // // IERC1155(_ERC1155).batchMint(from, ids, mintAmounts, "");

        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[0], abi.encode(keccak256("FOOBAR1"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[1], abi.encode(keccak256("FOOBAR2"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[2], abi.encode(keccak256("FOOBAR3"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[3], abi.encode(keccak256("FOOBAR4"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[4], abi.encode(keccak256("FOOBAR5"), abi.encode(address(0), 0, ""))
        );

        IERC1155(_ERC1155).setApprovalForAll(operator, true);

        vm.expectRevert();
        vm.prank(operator);
        IERC1155(_ERC1155).safeBatchTransferFrom(address(this), revertingERC1155Recipient, ids, transferAmounts, "");
    }

    function _testFailSafeBatchTransferFromToWrongReturnDataERC1155Recipient(address _ERC1155) internal {
        address operator = address(0xABCD);
        address wrongReturnDataERC1155Recipient = address(new WrongReturnDataERC1155Recipient());

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 50;
        transferAmounts[1] = 100;
        transferAmounts[2] = 150;
        transferAmounts[3] = 200;
        transferAmounts[4] = 250;

        // // IERC1155(_ERC1155).batchMint(from, ids, mintAmounts, "");

        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[0], abi.encode(keccak256("FOOBAR1"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[1], abi.encode(keccak256("FOOBAR2"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[2], abi.encode(keccak256("FOOBAR3"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[3], abi.encode(keccak256("FOOBAR4"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[4], abi.encode(keccak256("FOOBAR5"), abi.encode(address(0), 0, ""))
        );

        IERC1155(_ERC1155).setApprovalForAll(operator, true);

        vm.expectRevert();
        vm.prank(operator);
        //require(msg.sender == operator, "msg.sender != operator");
        IERC1155(_ERC1155).safeBatchTransferFrom(
            address(this), wrongReturnDataERC1155Recipient, ids, transferAmounts, ""
        );
    }

    function _testFailSafeBatchTransferFromWithArrayLengthMismatch(address _ERC1155) internal {
        address operator = address(0xABCD);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        uint256[] memory transferAmounts = new uint256[](4);
        transferAmounts[0] = 50;
        transferAmounts[1] = 100;
        transferAmounts[2] = 150;
        transferAmounts[3] = 200;

        // // IERC1155(_ERC1155).batchMint(from, ids, mintAmounts, "");

        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[0], abi.encode(keccak256("FOOBAR1"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[1], abi.encode(keccak256("FOOBAR2"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[2], abi.encode(keccak256("FOOBAR3"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[3], abi.encode(keccak256("FOOBAR4"), abi.encode(address(0), 0, ""))
        );
        IERC1155Mintable(_ERC1155).mint(
            address(this), mintAmounts[4], abi.encode(keccak256("FOOBAR5"), abi.encode(address(0), 0, ""))
        );

        IERC1155(_ERC1155).setApprovalForAll(operator, true);

        vm.expectRevert();
        vm.prank(operator);
        IERC1155(_ERC1155).safeBatchTransferFrom(address(this), address(0xBEEF), ids, transferAmounts, "");
    }

    function _testFailBatchMintToZero(address /*_ERC1155*/ ) internal pure {
        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        // IERC1155(_ERC1155).batchMint(address(0), ids, mintAmounts, "");
    }

    function _testFailBatchMintToNonERC1155Recipient(address /*_ERC1155*/ ) internal pure {
        // NonERC1155Recipient to = new NonERC1155Recipient();

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        // IERC1155(_ERC1155).batchMint(address(to), ids, mintAmounts, "");
    }

    function _testFailBatchMintToRevertingERC1155Recipient(address /*_ERC1155*/ ) internal pure {
        // RevertingERC1155Recipient to = new RevertingERC1155Recipient();

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        // IERC1155(_ERC1155).batchMint(address(to), ids, mintAmounts, "");
    }

    function _testFailBatchMintToWrongReturnDataERC1155Recipient(address /*_ERC1155*/ ) internal pure {
        // WrongReturnDataERC1155Recipient to = new WrongReturnDataERC1155Recipient();

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        // IERC1155(_ERC1155).batchMint(address(to), ids, mintAmounts, "");
    }

    function _testFailBatchMintWithArrayMismatch(address /*_ERC1155*/ ) internal pure {
        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;

        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;
        amounts[3] = 400;

        // IERC1155(_ERC1155).batchMint(address(0xBEEF), ids, amounts, "");
    }

    function _testFailBatchBurnInsufficientBalance(address /*_ERC1155*/ ) internal pure {
        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 50;
        mintAmounts[1] = 100;
        mintAmounts[2] = 150;
        mintAmounts[3] = 200;
        mintAmounts[4] = 250;

        uint256[] memory burnAmounts = new uint256[](5);
        burnAmounts[0] = 100;
        burnAmounts[1] = 200;
        burnAmounts[2] = 300;
        burnAmounts[3] = 400;
        burnAmounts[4] = 500;

        // IERC1155(_ERC1155).batchMint(address(0xBEEF), ids, mintAmounts, "");

        // IERC1155(_ERC1155).batchBurn(address(0xBEEF), ids, burnAmounts);
    }

    function _testFailBatchBurnWithArrayLengthMismatch(address /*_ERC1155*/ ) internal pure {
        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        uint256[] memory burnAmounts = new uint256[](4);
        burnAmounts[0] = 50;
        burnAmounts[1] = 100;
        burnAmounts[2] = 150;
        burnAmounts[3] = 200;

        // IERC1155(_ERC1155).batchMint(address(0xBEEF), ids, mintAmounts, "");

        // IERC1155(_ERC1155).batchBurn(address(0xBEEF), ids, burnAmounts);
    }

    function _testFailBalanceOfBatchWithArrayMismatch(address _ERC1155) internal {
        address[] memory tos = new address[](5);
        tos[0] = address(0xBEEF);
        tos[1] = address(0xCAFE);
        tos[2] = address(0xFACE);
        tos[3] = address(0xDEAD);
        tos[4] = address(0xFEED);

        uint256[] memory ids = new uint256[](4);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;

        vm.expectRevert();
        IERC1155(_ERC1155).balanceOfBatch(tos, ids);
    }

    /*----------------------------------------------------------*|
    |*  # FUZZING TESTS                                         *|
    |*----------------------------------------------------------*/

    // function testMintToEOA(
    //     address to,
    //     // uint256 id,
    //     uint256 amount,
    //     bytes32 tokenUri,
    //     address royaltyRecipient,
    //     uint96 royaltyBps,
    //     bytes memory mintData
    // ) internal {
    //     if (to == address(0)) to = address(0xBEEF);

    //     if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

    //     uint256 tokenId = IERC1155Supply(_ERC1155).totalSupply();

    //     IERC1155Mintable(_ERC1155).mint(
    //         to, amount, abi.encode(tokenUri, abi.encode(royaltyRecipient, royaltyBps, mintData))
    //     );

    //     assertEq(IERC1155(_ERC1155).balanceOf(to, tokenId), amount);
    // }

    // function _testMintToERC1155Recipient(
    //     uint256 id,
    //     uint256 amount,
    //     bytes memory mintData
    // ) internal {
    //     ERC1155Recipient to = new ERC1155Recipient();

    //     IERC1155(_ERC1155).mint(address(to), id, amount, mintData);

    //     assertEq(IERC1155(_ERC1155).balanceOf(address(to), id), amount);

    //     assertEq(to.operator(), address(this));
    //     assertEq(to.from(), address(0));
    //     assertEq(to.id(), id);
    //     assertBytesEq(to.mintData(), mintData);
    // }

    // function _testBatchMintToEOA(
    //     address to,
    //     uint256[] memory ids,
    //     uint256[] memory amounts,
    //     bytes memory mintData
    // ) internal {
    //     if (to == address(0)) to = address(0xBEEF);

    //     if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

    //     uint256 minLength = min2(ids.length, amounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[to][id];

    //         uint256 mintAmount = bound(amounts[i], 0, remainingMintAmountForId);

    //         normalizedIds[i] = id;
    //         normalizedAmounts[i] = mintAmount;

    //         userMintAmounts[to][id] += mintAmount;
    //     }

    // //     IERC1155(_ERC1155).batchMint(to, normalizedIds, normalizedAmounts, mintData);

    //     for (uint256 i = 0; i < normalizedIds.length; i++) {
    //         uint256 id = normalizedIds[i];

    //         assertEq(IERC1155(_ERC1155).balanceOf(to, id), userMintAmounts[to][id]);
    //     }
    // }

    // function _testBatchMintToERC1155Recipient(
    //     uint256[] memory ids,
    //     uint256[] memory amounts,
    //     bytes memory mintData
    // ) internal {
    //     ERC1155Recipient to = new ERC1155Recipient();

    //     uint256 minLength = min2(ids.length, amounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(to)][id];

    //         uint256 mintAmount = bound(amounts[i], 0, remainingMintAmountForId);

    //         normalizedIds[i] = id;
    //         normalizedAmounts[i] = mintAmount;

    //         userMintAmounts[address(to)][id] += mintAmount;
    //     }

    // //     IERC1155(_ERC1155).batchMint(address(to), normalizedIds, normalizedAmounts, mintData);

    //     assertEq(to.batchOperator(), address(this));
    //     assertEq(to.batchFrom(), address(0));
    //     assertUintArrayEq(to.batchIds(), normalizedIds);
    //     assertUintArrayEq(to.batchAmounts(), normalizedAmounts);
    //     assertBytesEq(to.batchData(), mintData);

    //     for (uint256 i = 0; i < normalizedIds.length; i++) {
    //         uint256 id = normalizedIds[i];

    //         assertEq(IERC1155(_ERC1155).balanceOf(address(to), id), userMintAmounts[address(to)][id]);
    //     }
    // }

    // function _testBurn(
    //     address to,
    //     uint256 id,
    //     uint256 mintAmount,
    //     bytes memory mintData,
    //     uint256 burnAmount
    // ) internal {
    //     if (to == address(0)) to = address(0xBEEF);

    //     if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

    //     burnAmount = bound(burnAmount, 0, mintAmount);

    //     IERC1155(_ERC1155).mint(to, id, mintAmount, mintData);

    //     IERC1155(_ERC1155).burn(to, id, burnAmount);

    //     assertEq(IERC1155(_ERC1155).balanceOf(address(to), id), mintAmount - burnAmount);
    // }

    // function _testBatchBurn(
    //     address to,
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory burnAmounts,
    //     bytes memory mintData
    // ) internal {
    //     if (to == address(0)) to = address(0xBEEF);

    //     if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

    //     uint256 minLength = min3(ids.length, mintAmounts.length, burnAmounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedMintAmounts = new uint256[](minLength);
    //     uint256[] memory normalizedBurnAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(to)][id];

    //         normalizedIds[i] = id;
    //         normalizedMintAmounts[i] = bound(mintAmounts[i], 0, remainingMintAmountForId);
    //         normalizedBurnAmounts[i] = bound(burnAmounts[i], 0, normalizedMintAmounts[i]);

    //         userMintAmounts[address(to)][id] += normalizedMintAmounts[i];
    //         userTransferOrBurnAmounts[address(to)][id] += normalizedBurnAmounts[i];
    //     }

    // //     IERC1155(_ERC1155).batchMint(to, normalizedIds, normalizedMintAmounts, mintData);

    // //     IERC1155(_ERC1155).batchBurn(to, normalizedIds, normalizedBurnAmounts);

    //     for (uint256 i = 0; i < normalizedIds.length; i++) {
    //         uint256 id = normalizedIds[i];

    //         assertEq(IERC1155(_ERC1155).balanceOf(to, id), userMintAmounts[to][id] -
    // userTransferOrBurnAmounts[to][id]);
    //     }
    // }

    // function _testApproveAll(address to, bool approved) internal {
    //     IERC1155(_ERC1155).setApprovalForAll(to, approved);

    //     assertBoolEq(IERC1155(_ERC1155).isApprovedForAll(address(this), to), approved);
    // }

    // function _testSafeTransferFromToEOA(
    //     uint256 id,
    //     uint256 mintAmount,
    //     bytes memory mintData,
    //     uint256 transferAmount,
    //     address to,
    //     bytes memory transferData
    // ) internal {
    //     if (to == address(0)) to = address(0xBEEF);

    //     if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

    //     transferAmount = bound(transferAmount, 0, mintAmount);

    //     address from = address(0xABCD);

    //     IERC1155(_ERC1155).mint(from, id, mintAmount, mintData);

    //     hevm.prank(from);
    //     IERC1155(_ERC1155).setApprovalForAll(address(this), true);

    //     IERC1155(_ERC1155).safeTransferFrom(from, to, id, transferAmount, transferData);

    //     if (to == from) {
    //         assertEq(IERC1155(_ERC1155).balanceOf(to, id), mintAmount);
    //     } else {
    //         assertEq(IERC1155(_ERC1155).balanceOf(to, id), transferAmount);
    //         assertEq(IERC1155(_ERC1155).balanceOf(from, id), mintAmount - transferAmount);
    //     }
    // }

    // function _testSafeTransferFromToERC1155Recipient(
    //     uint256 id,
    //     uint256 mintAmount,
    //     bytes memory mintData,
    //     uint256 transferAmount,
    //     bytes memory transferData
    // ) internal {
    //     ERC1155Recipient to = new ERC1155Recipient();

    //     address from = address(0xABCD);

    //     transferAmount = bound(transferAmount, 0, mintAmount);

    //     IERC1155(_ERC1155).mint(from, id, mintAmount, mintData);

    //     hevm.prank(from);
    //     IERC1155(_ERC1155).setApprovalForAll(address(this), true);

    //     IERC1155(_ERC1155).safeTransferFrom(from, address(to), id, transferAmount, transferData);

    //     assertEq(to.operator(), address(this));
    //     assertEq(to.from(), from);
    //     assertEq(to.id(), id);
    //     assertBytesEq(to.mintData(), transferData);

    //     assertEq(IERC1155(_ERC1155).balanceOf(address(to), id), transferAmount);
    //     assertEq(IERC1155(_ERC1155).balanceOf(from, id), mintAmount - transferAmount);
    // }

    // function _testSafeTransferFromSelf(
    //     uint256 id,
    //     uint256 mintAmount,
    //     bytes memory mintData,
    //     uint256 transferAmount,
    //     address to,
    //     bytes memory transferData
    // ) internal {
    //     if (to == address(0)) to = address(0xBEEF);

    //     if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

    //     transferAmount = bound(transferAmount, 0, mintAmount);

    //     IERC1155(_ERC1155).mint(address(this), id, mintAmount, mintData);

    //     IERC1155(_ERC1155).safeTransferFrom(address(this), to, id, transferAmount, transferData);

    //     assertEq(IERC1155(_ERC1155).balanceOf(to, id), transferAmount);
    //     assertEq(IERC1155(_ERC1155).balanceOf(address(this), id), mintAmount - transferAmount);
    // }

    // function _testSafeBatchTransferFromToEOA(
    //     address to,
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory transferAmounts,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) internal {
    //     if (to == address(0)) to = address(0xBEEF);

    //     if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

    //     address from = address(0xABCD);

    //     uint256 minLength = min3(ids.length, mintAmounts.length, transferAmounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedMintAmounts = new uint256[](minLength);
    //     uint256[] memory normalizedTransferAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[from][id];

    //         uint256 mintAmount = bound(mintAmounts[i], 0, remainingMintAmountForId);
    //         uint256 transferAmount = bound(transferAmounts[i], 0, mintAmount);

    //         normalizedIds[i] = id;
    //         normalizedMintAmounts[i] = mintAmount;
    //         normalizedTransferAmounts[i] = transferAmount;

    //         userMintAmounts[from][id] += mintAmount;
    //         userTransferOrBurnAmounts[from][id] += transferAmount;
    //     }

    // //     IERC1155(_ERC1155).batchMint(from, normalizedIds, normalizedMintAmounts, mintData);

    //     hevm.prank(from);
    //     IERC1155(_ERC1155).setApprovalForAll(address(this), true);

    //     IERC1155(_ERC1155).safeBatchTransferFrom(from, to, normalizedIds, normalizedTransferAmounts, transferData);

    //     for (uint256 i = 0; i < normalizedIds.length; i++) {
    //         uint256 id = normalizedIds[i];

    //         assertEq(IERC1155(_ERC1155).balanceOf(address(to), id), userTransferOrBurnAmounts[from][id]);
    //         assertEq(IERC1155(_ERC1155).balanceOf(from, id), userMintAmounts[from][id] -
    // userTransferOrBurnAmounts[from][id]);
    //     }
    // }

    // function _testSafeBatchTransferFromToERC1155Recipient(
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory transferAmounts,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) internal {
    //     address from = address(0xABCD);

    //     ERC1155Recipient to = new ERC1155Recipient();

    //     uint256 minLength = min3(ids.length, mintAmounts.length, transferAmounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedMintAmounts = new uint256[](minLength);
    //     uint256[] memory normalizedTransferAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[from][id];

    //         uint256 mintAmount = bound(mintAmounts[i], 0, remainingMintAmountForId);
    //         uint256 transferAmount = bound(transferAmounts[i], 0, mintAmount);

    //         normalizedIds[i] = id;
    //         normalizedMintAmounts[i] = mintAmount;
    //         normalizedTransferAmounts[i] = transferAmount;

    //         userMintAmounts[from][id] += mintAmount;
    //         userTransferOrBurnAmounts[from][id] += transferAmount;
    //     }

    // //     IERC1155(_ERC1155).batchMint(from, normalizedIds, normalizedMintAmounts, mintData);

    //     hevm.prank(from);
    //     IERC1155(_ERC1155).setApprovalForAll(address(this), true);

    //     IERC1155(_ERC1155).safeBatchTransferFrom(from, address(to), normalizedIds, normalizedTransferAmounts,
    // transferData);

    //     assertEq(to.batchOperator(), address(this));
    //     assertEq(to.batchFrom(), from);
    //     assertUintArrayEq(to.batchIds(), normalizedIds);
    //     assertUintArrayEq(to.batchAmounts(), normalizedTransferAmounts);
    //     assertBytesEq(to.batchData(), transferData);

    //     for (uint256 i = 0; i < normalizedIds.length; i++) {
    //         uint256 id = normalizedIds[i];
    //         uint256 transferAmount = userTransferOrBurnAmounts[from][id];

    //         assertEq(IERC1155(_ERC1155).balanceOf(address(to), id), transferAmount);
    //         assertEq(IERC1155(_ERC1155).balanceOf(from, id), userMintAmounts[from][id] - transferAmount);
    //     }
    // }

    // function _testBatchBalanceOf(
    //     address[] memory tos,
    //     uint256[] memory ids,
    //     uint256[] memory amounts,
    //     bytes memory mintData
    // ) internal {
    //     uint256 minLength = min3(tos.length, ids.length, amounts.length);

    //     address[] memory normalizedTos = new address[](minLength);
    //     uint256[] memory normalizedIds = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];
    //         address to = tos[i] == address(0) || tos[i].code.length > 0 ? address(0xBEEF) : tos[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[to][id];

    //         normalizedTos[i] = to;
    //         normalizedIds[i] = id;

    //         uint256 mintAmount = bound(amounts[i], 0, remainingMintAmountForId);

    //         IERC1155(_ERC1155).mint(to, id, mintAmount, mintData);

    //         userMintAmounts[to][id] += mintAmount;
    //     }

    //     uint256[] memory balances = IERC1155(_ERC1155).balanceOfBatch(normalizedTos, normalizedIds);

    //     for (uint256 i = 0; i < normalizedTos.length; i++) {
    //         assertEq(balances[i], IERC1155(_ERC1155).balanceOf(normalizedTos[i], normalizedIds[i]));
    //     }
    // }

    // function _testFailMintToZero(
    //     uint256 id,
    //     uint256 amount,
    //     bytes memory data
    // ) internal {
    //     IERC1155(_ERC1155).mint(address(0), id, amount, data);
    // }

    // function _testFailMintToNonERC1155Recipient(
    //     uint256 id,
    //     uint256 mintAmount,
    //     bytes memory mintData
    // ) internal {
    //     IERC1155(_ERC1155).mint(address(new NonERC1155Recipient()), id, mintAmount, mintData);
    // }

    // function _testFailMintToRevertingERC1155Recipient(
    //     uint256 id,
    //     uint256 mintAmount,
    //     bytes memory mintData
    // ) internal {
    //     IERC1155(_ERC1155).mint(address(new RevertingERC1155Recipient()), id, mintAmount, mintData);
    // }

    // function _testFailMintToWrongReturnDataERC1155Recipient(
    //     uint256 id,
    //     uint256 mintAmount,
    //     bytes memory mintData
    // ) internal {
    //     IERC1155(_ERC1155).mint(address(new RevertingERC1155Recipient()), id, mintAmount, mintData);
    // }

    // function _testFailBurnInsufficientBalance(
    //     address to,
    //     uint256 id,
    //     uint256 mintAmount,
    //     uint256 burnAmount,
    //     bytes memory mintData
    // ) internal {
    //     burnAmount = bound(burnAmount, mintAmount + 1, type(uint256).max);

    //     IERC1155(_ERC1155).mint(to, id, mintAmount, mintData);
    //     IERC1155(_ERC1155).burn(to, id, burnAmount);
    // }

    // function _testFailSafeTransferFromInsufficientBalance(
    //     address to,
    //     uint256 id,
    //     uint256 mintAmount,
    //     uint256 transferAmount,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) internal {
    //     address from = address(0xABCD);

    //     transferAmount = bound(transferAmount, mintAmount + 1, type(uint256).max);

    //     IERC1155(_ERC1155).mint(from, id, mintAmount, mintData);

    //     hevm.prank(from);
    //     IERC1155(_ERC1155).setApprovalForAll(address(this), true);

    //     IERC1155(_ERC1155).safeTransferFrom(from, to, id, transferAmount, transferData);
    // }

    // function _testFailSafeTransferFromSelfInsufficientBalance(
    //     address to,
    //     uint256 id,
    //     uint256 mintAmount,
    //     uint256 transferAmount,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) internal {
    //     transferAmount = bound(transferAmount, mintAmount + 1, type(uint256).max);

    //     IERC1155(_ERC1155).mint(address(this), id, mintAmount, mintData);
    //     IERC1155(_ERC1155).safeTransferFrom(address(this), to, id, transferAmount, transferData);
    // }

    // function _testFailSafeTransferFromToZero(
    //     uint256 id,
    //     uint256 mintAmount,
    //     uint256 transferAmount,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) internal {
    //     transferAmount = bound(transferAmount, 0, mintAmount);

    //     IERC1155(_ERC1155).mint(address(this), id, mintAmount, mintData);
    //     IERC1155(_ERC1155).safeTransferFrom(address(this), address(0), id, transferAmount, transferData);
    // }

    // function _testFailSafeTransferFromToNonERC1155Recipient(
    //     uint256 id,
    //     uint256 mintAmount,
    //     uint256 transferAmount,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) internal {
    //     transferAmount = bound(transferAmount, 0, mintAmount);

    //     IERC1155(_ERC1155).mint(address(this), id, mintAmount, mintData);
    //     IERC1155(_ERC1155).safeTransferFrom(address(this), address(new NonERC1155Recipient()), id, transferAmount,
    // transferData);
    // }

    // function _testFailSafeTransferFromToRevertingERC1155Recipient(
    //     uint256 id,
    //     uint256 mintAmount,
    //     uint256 transferAmount,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) internal {
    //     transferAmount = bound(transferAmount, 0, mintAmount);

    //     IERC1155(_ERC1155).mint(address(this), id, mintAmount, mintData);
    //     IERC1155(_ERC1155).safeTransferFrom(
    //         address(this),
    //         address(new RevertingERC1155Recipient()),
    //         id,
    //         transferAmount,
    //         transferData
    //     );
    // }

    // function _testFailSafeTransferFromToWrongReturnDataERC1155Recipient(
    //     uint256 id,
    //     uint256 mintAmount,
    //     uint256 transferAmount,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) internal {
    //     transferAmount = bound(transferAmount, 0, mintAmount);

    //     IERC1155(_ERC1155).mint(address(this), id, mintAmount, mintData);
    //     IERC1155(_ERC1155).safeTransferFrom(
    //         address(this),
    //         address(new WrongReturnDataERC1155Recipient()),
    //         id,
    //         transferAmount,
    //         transferData
    //     );
    // }

    // function _testFailSafeBatchTransferInsufficientBalance(
    //     address to,
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory transferAmounts,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) internal {
    //     address from = address(0xABCD);

    //     uint256 minLength = min3(ids.length, mintAmounts.length, transferAmounts.length);

    //     if (minLength == 0) revert();

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedMintAmounts = new uint256[](minLength);
    //     uint256[] memory normalizedTransferAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[from][id];

    //         uint256 mintAmount = bound(mintAmounts[i], 0, remainingMintAmountForId);
    //         uint256 transferAmount = bound(transferAmounts[i], mintAmount + 1, type(uint256).max);

    //         normalizedIds[i] = id;
    //         normalizedMintAmounts[i] = mintAmount;
    //         normalizedTransferAmounts[i] = transferAmount;

    //         userMintAmounts[from][id] += mintAmount;
    //     }

    // //     IERC1155(_ERC1155).batchMint(from, normalizedIds, normalizedMintAmounts, mintData);

    //     hevm.prank(from);
    //     IERC1155(_ERC1155).setApprovalForAll(address(this), true);

    //     IERC1155(_ERC1155).safeBatchTransferFrom(from, to, normalizedIds, normalizedTransferAmounts, transferData);
    // }

    // function _testFailSafeBatchTransferFromToZero(
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory transferAmounts,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) internal {
    //     address from = address(0xABCD);

    //     uint256 minLength = min3(ids.length, mintAmounts.length, transferAmounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedMintAmounts = new uint256[](minLength);
    //     uint256[] memory normalizedTransferAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[from][id];

    //         uint256 mintAmount = bound(mintAmounts[i], 0, remainingMintAmountForId);
    //         uint256 transferAmount = bound(transferAmounts[i], 0, mintAmount);

    //         normalizedIds[i] = id;
    //         normalizedMintAmounts[i] = mintAmount;
    //         normalizedTransferAmounts[i] = transferAmount;

    //         userMintAmounts[from][id] += mintAmount;
    //     }

    // //     IERC1155(_ERC1155).batchMint(from, normalizedIds, normalizedMintAmounts, mintData);

    //     hevm.prank(from);
    //     IERC1155(_ERC1155).setApprovalForAll(address(this), true);

    //     IERC1155(_ERC1155).safeBatchTransferFrom(from, address(0), normalizedIds, normalizedTransferAmounts,
    // transferData);
    // }

    // function _testFailSafeBatchTransferFromToNonERC1155Recipient(
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory transferAmounts,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) internal {
    //     address from = address(0xABCD);

    //     uint256 minLength = min3(ids.length, mintAmounts.length, transferAmounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedMintAmounts = new uint256[](minLength);
    //     uint256[] memory normalizedTransferAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[from][id];

    //         uint256 mintAmount = bound(mintAmounts[i], 0, remainingMintAmountForId);
    //         uint256 transferAmount = bound(transferAmounts[i], 0, mintAmount);

    //         normalizedIds[i] = id;
    //         normalizedMintAmounts[i] = mintAmount;
    //         normalizedTransferAmounts[i] = transferAmount;

    //         userMintAmounts[from][id] += mintAmount;
    //     }

    // //     IERC1155(_ERC1155).batchMint(from, normalizedIds, normalizedMintAmounts, mintData);

    //     hevm.prank(from);
    //     IERC1155(_ERC1155).setApprovalForAll(address(this), true);

    //     IERC1155(_ERC1155).safeBatchTransferFrom(
    //         from,
    //         address(new NonERC1155Recipient()),
    //         normalizedIds,
    //         normalizedTransferAmounts,
    //         transferData
    //     );
    // }

    // function _testFailSafeBatchTransferFromToRevertingERC1155Recipient(
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory transferAmounts,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) internal {
    //     address from = address(0xABCD);

    //     uint256 minLength = min3(ids.length, mintAmounts.length, transferAmounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedMintAmounts = new uint256[](minLength);
    //     uint256[] memory normalizedTransferAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[from][id];

    //         uint256 mintAmount = bound(mintAmounts[i], 0, remainingMintAmountForId);
    //         uint256 transferAmount = bound(transferAmounts[i], 0, mintAmount);

    //         normalizedIds[i] = id;
    //         normalizedMintAmounts[i] = mintAmount;
    //         normalizedTransferAmounts[i] = transferAmount;

    //         userMintAmounts[from][id] += mintAmount;
    //     }

    // //     IERC1155(_ERC1155).batchMint(from, normalizedIds, normalizedMintAmounts, mintData);

    //     hevm.prank(from);
    //     IERC1155(_ERC1155).setApprovalForAll(address(this), true);

    //     IERC1155(_ERC1155).safeBatchTransferFrom(
    //         from,
    //         address(new RevertingERC1155Recipient()),
    //         normalizedIds,
    //         normalizedTransferAmounts,
    //         transferData
    //     );
    // }

    // function _testFailSafeBatchTransferFromToWrongReturnDataERC1155Recipient(
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory transferAmounts,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) internal {
    //     address from = address(0xABCD);

    //     uint256 minLength = min3(ids.length, mintAmounts.length, transferAmounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedMintAmounts = new uint256[](minLength);
    //     uint256[] memory normalizedTransferAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[from][id];

    //         uint256 mintAmount = bound(mintAmounts[i], 0, remainingMintAmountForId);
    //         uint256 transferAmount = bound(transferAmounts[i], 0, mintAmount);

    //         normalizedIds[i] = id;
    //         normalizedMintAmounts[i] = mintAmount;
    //         normalizedTransferAmounts[i] = transferAmount;

    //         userMintAmounts[from][id] += mintAmount;
    //     }

    // //     IERC1155(_ERC1155).batchMint(from, normalizedIds, normalizedMintAmounts, mintData);

    //     hevm.prank(from);
    //     IERC1155(_ERC1155).setApprovalForAll(address(this), true);

    //     IERC1155(_ERC1155).safeBatchTransferFrom(
    //         from,
    //         address(new WrongReturnDataERC1155Recipient()),
    //         normalizedIds,
    //         normalizedTransferAmounts,
    //         transferData
    //     );
    // }

    // function _testFailSafeBatchTransferFromWithArrayLengthMismatch(
    //     address to,
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory transferAmounts,
    //     bytes memory mintData,
    //     bytes memory transferData
    // ) internal {
    //     address from = address(0xABCD);

    //     if (ids.length == transferAmounts.length) revert();

    // //     IERC1155(_ERC1155).batchMint(from, ids, mintAmounts, mintData);

    //     hevm.prank(from);
    //     IERC1155(_ERC1155).setApprovalForAll(address(this), true);

    //     IERC1155(_ERC1155).safeBatchTransferFrom(from, to, ids, transferAmounts, transferData);
    // }

    // function _testFailBatchMintToZero(
    //     uint256[] memory ids,
    //     uint256[] memory amounts,
    //     bytes memory mintData
    // ) internal {
    //     uint256 minLength = min2(ids.length, amounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(0)][id];

    //         uint256 mintAmount = bound(amounts[i], 0, remainingMintAmountForId);

    //         normalizedIds[i] = id;
    //         normalizedAmounts[i] = mintAmount;

    //         userMintAmounts[address(0)][id] += mintAmount;
    //     }

    // //     IERC1155(_ERC1155).batchMint(address(0), normalizedIds, normalizedAmounts, mintData);
    // }

    // function _testFailBatchMintToNonERC1155Recipient(
    //     uint256[] memory ids,
    //     uint256[] memory amounts,
    //     bytes memory mintData
    // ) internal {
    //     NonERC1155Recipient to = new NonERC1155Recipient();

    //     uint256 minLength = min2(ids.length, amounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(to)][id];

    //         uint256 mintAmount = bound(amounts[i], 0, remainingMintAmountForId);

    //         normalizedIds[i] = id;
    //         normalizedAmounts[i] = mintAmount;

    //         userMintAmounts[address(to)][id] += mintAmount;
    //     }

    // //     IERC1155(_ERC1155).batchMint(address(to), normalizedIds, normalizedAmounts, mintData);
    // }

    // function _testFailBatchMintToRevertingERC1155Recipient(
    //     uint256[] memory ids,
    //     uint256[] memory amounts,
    //     bytes memory mintData
    // ) internal {
    //     RevertingERC1155Recipient to = new RevertingERC1155Recipient();

    //     uint256 minLength = min2(ids.length, amounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(to)][id];

    //         uint256 mintAmount = bound(amounts[i], 0, remainingMintAmountForId);

    //         normalizedIds[i] = id;
    //         normalizedAmounts[i] = mintAmount;

    //         userMintAmounts[address(to)][id] += mintAmount;
    //     }

    // //     IERC1155(_ERC1155).batchMint(address(to), normalizedIds, normalizedAmounts, mintData);
    // }

    // function _testFailBatchMintToWrongReturnDataERC1155Recipient(
    //     uint256[] memory ids,
    //     uint256[] memory amounts,
    //     bytes memory mintData
    // ) internal {
    //     WrongReturnDataERC1155Recipient to = new WrongReturnDataERC1155Recipient();

    //     uint256 minLength = min2(ids.length, amounts.length);

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[address(to)][id];

    //         uint256 mintAmount = bound(amounts[i], 0, remainingMintAmountForId);

    //         normalizedIds[i] = id;
    //         normalizedAmounts[i] = mintAmount;

    //         userMintAmounts[address(to)][id] += mintAmount;
    //     }

    // //     IERC1155(_ERC1155).batchMint(address(to), normalizedIds, normalizedAmounts, mintData);
    // }

    // function _testFailBatchMintWithArrayMismatch(
    //     address to,
    //     uint256[] memory ids,
    //     uint256[] memory amounts,
    //     bytes memory mintData
    // ) internal {
    //     if (ids.length == amounts.length) revert();

    // //     IERC1155(_ERC1155).batchMint(address(to), ids, amounts, mintData);
    // }

    // function _testFailBatchBurnInsufficientBalance(
    //     address to,
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory burnAmounts,
    //     bytes memory mintData
    // ) internal {
    //     uint256 minLength = min3(ids.length, mintAmounts.length, burnAmounts.length);

    //     if (minLength == 0) revert();

    //     uint256[] memory normalizedIds = new uint256[](minLength);
    //     uint256[] memory normalizedMintAmounts = new uint256[](minLength);
    //     uint256[] memory normalizedBurnAmounts = new uint256[](minLength);

    //     for (uint256 i = 0; i < minLength; i++) {
    //         uint256 id = ids[i];

    //         uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[to][id];

    //         normalizedIds[i] = id;
    //         normalizedMintAmounts[i] = bound(mintAmounts[i], 0, remainingMintAmountForId);
    //         normalizedBurnAmounts[i] = bound(burnAmounts[i], normalizedMintAmounts[i] + 1, type(uint256).max);

    //         userMintAmounts[to][id] += normalizedMintAmounts[i];
    //     }

    // //     IERC1155(_ERC1155).batchMint(to, normalizedIds, normalizedMintAmounts, mintData);

    // //     IERC1155(_ERC1155).batchBurn(to, normalizedIds, normalizedBurnAmounts);
    // }

    // function _testFailBatchBurnWithArrayLengthMismatch(
    //     address to,
    //     uint256[] memory ids,
    //     uint256[] memory mintAmounts,
    //     uint256[] memory burnAmounts,
    //     bytes memory mintData
    // ) internal {
    //     if (ids.length == burnAmounts.length) revert();

    // //     IERC1155(_ERC1155).batchMint(to, ids, mintAmounts, mintData);

    // //     IERC1155(_ERC1155).batchBurn(to, ids, burnAmounts);
    // }

    // function _testFailBalanceOfBatchWithArrayMismatch(address[] memory tos, uint256[] memory ids) internal view {
    //     if (tos.length == ids.length) revert();

    //     IERC1155(_ERC1155).balanceOfBatch(tos, ids);
    // }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return 0xf23a6e61;
    }
}
