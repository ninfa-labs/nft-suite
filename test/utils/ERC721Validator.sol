// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import {
    ERC721Recipient,
    RevertingERC721Recipient,
    WrongReturnDataERC721Recipient,
    NonERC721Recipient
} from "test/utils/mocks/ERC721Recipient.sol";
import "test/utils/mocks/ERC1271.sol";
import "test/interfaces/IERC165.sol";
import "test/interfaces/IERC721.sol";
import "test/interfaces/IERC721Enumerable.sol";
import "test/interfaces/IERC721LazyMint.sol";

abstract contract ERC721Validator is Test, ERC721Recipient, ERC1271 {
    /*----------------------------------------------------------*|
    |*  # INTERFACES AND EXTENSIONS                             *|
    |*----------------------------------------------------------*/

    function _testSupportsInterface(address _ERC721) internal view {
        assertEq(IERC165(_ERC721).supportsInterface(0x01ffc9a7), true); // type(IERC165).interfaceId
        assertEq(IERC165(_ERC721).supportsInterface(0x80ac58cd), true); // type(IERC721).interfaceId
        assertEq(IERC165(_ERC721).supportsInterface(0x780e9d63), true); // type(IERC721Enumerable).interfaceId
        assertEq(IERC165(_ERC721).supportsInterface(0x5b5e139f), true); // type(IERC721Metadata).interfaceId
        assertEq(IERC165(_ERC721).supportsInterface(0x2a55205a), true); // type(IERC2981).interfaceId
        assertEq(IERC165(_ERC721).supportsInterface(0x7965db0b), true); // type(IAccessControl).interfaceId
    }

    function _testERC721Metadata_URI(address _ERC721) internal view {
        string memory tokenURI = IERC721LazyMint(_ERC721).tokenURI(0);
        // since 32 bytes is the length of the ipfs hash,
        // the tokenURI should be longer than that including `baseURI` such as ipfs://
        assertEq(bytes(tokenURI).length > 32, true);
    }

    function _testERC721Enumerable(address _ERC721) internal view {
        /// @dev tokenByIndex(0) should not throw.
        assertEq(IERC721LazyMint(_ERC721).tokenByIndex(0), 0);

        uint256 totalSupply = IERC721LazyMint(_ERC721).totalSupply();
        uint256 totalBalance = 0;

        address[] memory uniqueAddresses = new address[](totalSupply);
        uint256 uniqueAddressesCount = 0;

        for (uint256 i = 0; i < totalSupply; i++) {
            address currentOwner = IERC721(_ERC721).ownerOf(i);
            bool alreadySeen = false;

            for (uint256 j = 0; j < uniqueAddressesCount; j++) {
                if (uniqueAddresses[j] == currentOwner) {
                    alreadySeen = true;
                    break;
                }
            }

            if (!alreadySeen) {
                uniqueAddresses[uniqueAddressesCount] = currentOwner;
                uniqueAddressesCount++;
                totalBalance += IERC721(_ERC721).balanceOf(currentOwner);
            }
        }
        /// @dev The sum of all user balances must be equal to the total supply
        assertEq(totalSupply, totalBalance);
    }

    /*----------------------------------------------------------*|
    |*  # MODIFIED SOLMATE TESTS                                *|
    |*----------------------------------------------------------*/

    /// @dev modified Solmate function interface, name and symbol are optional, pass "" if name and symbol are not known
    function _invariant_ERC721Metadata(address _ERC721, string memory _name, string memory _symbol) internal view {
        if (bytes(_name).length > 0) {
            assertEq(IERC721LazyMint(_ERC721).name(), _name, "wrong name");
        } else {
            _name = IERC721LazyMint(_ERC721).name();
            assertEq(bytes(_name).length > 0, true, "no name");
        }

        if (bytes(_symbol).length > 0) {
            assertEq(IERC721LazyMint(_ERC721).symbol(), _symbol, "wrong symbol");
        } else {
            _symbol = IERC721LazyMint(_ERC721).symbol();
            assertEq(bytes(_symbol).length > 0, true, "no symbol");
        }
    }

    function _testMint(address _ERC721) internal view {
        assertEq(IERC721(_ERC721).balanceOf(address(this)), 1);
        assertEq(IERC721(_ERC721).ownerOf(0), address(this));
    }

    function _testBurn(address _ERC721) internal {
        IERC721LazyMint(_ERC721).burn(0);

        assertEq(IERC721(_ERC721).balanceOf(address(this)), 0);
        vm.expectRevert();
        IERC721(_ERC721).ownerOf(0);
    }

    function _testApprove(address _ERC721) internal {
        IERC721(_ERC721).approve(address(0xABCD), 0);

        assertEq(IERC721(_ERC721).getApproved(0), address(0xABCD));
    }

    function _testApproveBurn(address _ERC721) internal {
        IERC721(_ERC721).approve(address(0xABCD), 0);

        IERC721LazyMint(_ERC721).burn(0);

        assertEq(IERC721(_ERC721).balanceOf(address(this)), 0);

        vm.expectRevert();
        IERC721(_ERC721).getApproved(0);

        vm.expectRevert();
        IERC721(_ERC721).ownerOf(0);
    }

    function _testApproveAll(address _ERC721) internal {
        IERC721(_ERC721).setApprovalForAll(address(0xABCD), true);

        assertTrue(IERC721(_ERC721).isApprovedForAll(address(this), address(0xABCD)));
    }

    function _testTransferFrom(address _ERC721) internal {
        IERC721(_ERC721).approve(address(0xABCD), 0);

        vm.prank(address(0xABCD));
        IERC721(_ERC721).transferFrom(address(this), address(0xABCD), 0);

        assertEq(IERC721(_ERC721).getApproved(0), address(0));
        assertEq(IERC721(_ERC721).ownerOf(0), address(0xABCD));
        assertEq(IERC721(_ERC721).balanceOf(address(0xABCD)), 1);
        assertEq(IERC721(_ERC721).balanceOf(address(this)), 0);
    }

    function _testTransferFromSelf(address _ERC721) internal {
        IERC721(_ERC721).transferFrom(address(this), address(0xABCD), 0);

        assertEq(IERC721(_ERC721).getApproved(0), address(0));
        assertEq(IERC721(_ERC721).ownerOf(0), address(0xABCD));
        assertEq(IERC721(_ERC721).balanceOf(address(0xABCD)), 1);
        assertEq(IERC721(_ERC721).balanceOf(address(this)), 0);
    }

    function _testTransferFromApproveAll(address _ERC721) internal {
        IERC721(_ERC721).setApprovalForAll(address(0xABCD), true);

        vm.prank(address(0xABCD));
        IERC721(_ERC721).transferFrom(address(this), address(0xABCD), 0);

        assertEq(IERC721(_ERC721).getApproved(0), address(0));
        assertEq(IERC721(_ERC721).ownerOf(0), address(0xABCD));
        assertEq(IERC721(_ERC721).balanceOf(address(0xABCD)), 1);
        assertEq(IERC721(_ERC721).balanceOf(address(this)), 0);
    }

    function _testSafeTransferFromToEOA(address _ERC721) internal {
        IERC721(_ERC721).setApprovalForAll(address(0xABCD), true);

        vm.prank(address(0xABCD));
        IERC721(_ERC721).safeTransferFrom(address(this), address(0xABCD), 0);

        assertEq(IERC721(_ERC721).getApproved(0), address(0));
        assertEq(IERC721(_ERC721).ownerOf(0), address(0xABCD));
        assertEq(IERC721(_ERC721).balanceOf(address(0xABCD)), 1);
        assertEq(IERC721(_ERC721).balanceOf(address(this)), 0);
    }

    function _testSafeTransferFromToERC721Recipient(address _ERC721) internal {
        IERC721(_ERC721).setApprovalForAll(address(0xABCD), true);

        ERC721Recipient recipient = new ERC721Recipient();

        vm.prank(address(0xABCD));
        IERC721(_ERC721).safeTransferFrom(address(this), address(recipient), 0);

        assertEq(IERC721(_ERC721).getApproved(0), address(0));
        assertEq(IERC721(_ERC721).ownerOf(0), address(recipient));
        assertEq(IERC721(_ERC721).balanceOf(address(recipient)), 1);
        assertEq(IERC721(_ERC721).balanceOf(address(this)), 0);

        assertEq(recipient.operator(), address(0xABCD));
        assertEq(recipient.from(), address(this));
        assertEq(recipient.id(), 0);
        assertEq(recipient.data(), "");
    }

    function _testSafeTransferFromToERC721RecipientWithData(address _ERC721) internal {
        ERC721Recipient recipient = new ERC721Recipient();

        IERC721(_ERC721).setApprovalForAll(address(0xABCD), true);

        vm.prank(address(0xABCD));
        IERC721(_ERC721).safeTransferFrom(address(this), address(recipient), 0, "testing 123");

        assertEq(IERC721(_ERC721).getApproved(0), address(0));
        assertEq(IERC721(_ERC721).ownerOf(0), address(recipient));
        assertEq(IERC721(_ERC721).balanceOf(address(recipient)), 1);
        assertEq(IERC721(_ERC721).balanceOf(address(this)), 0);

        assertEq(recipient.operator(), address(0xABCD));
        assertEq(recipient.from(), address(this));
        assertEq(recipient.id(), 0);
        assertEq(recipient.data(), "testing 123");
    }

    function _testSafeMintToERC721Recipient(address _ERC721, address _royaltyRecipient, uint96 _royaltyBps) internal {
        ERC721Recipient to = new ERC721Recipient();
        IERC721(_ERC721).mint(
            address(to), abi.encode(bytes32("foobar"), abi.encode(_royaltyRecipient, _royaltyBps, ""))
        );

        assertEq(IERC721(_ERC721).ownerOf(1), address(to));
        assertEq(IERC721(_ERC721).balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), 1);
        assertEq(to.data(), "");
    }

    function _testSafeMintToERC721RecipientWithData(
        address _ERC721,
        address _royaltyRecipient,
        uint96 _royaltyBps
    )
        internal
    {
        ERC721Recipient to = new ERC721Recipient();

        IERC721(_ERC721).mint(
            address(to), abi.encode(bytes32("foobar"), abi.encode(_royaltyRecipient, _royaltyBps, "testing 123"))
        );

        assertEq(IERC721(_ERC721).ownerOf(1), address(to));
        assertEq(IERC721(_ERC721).balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), 1);
        assertEq(to.data(), "testing 123");
    }

    function _testFailMintToZero(address _ERC721, address _royaltyRecipient, uint96 _royaltyBps) internal {
        vm.expectRevert();
        IERC721(_ERC721).mint(address(0), abi.encode(bytes32("foobar"), abi.encode(_royaltyRecipient, _royaltyBps, "")));
    }

    function _testFailDoubleMint(address _ERC721, address _royaltyRecipient, uint96 _royaltyBps) internal {
        IERC721(_ERC721).mint(
            address(this), abi.encode(bytes32("foobar"), abi.encode(_royaltyRecipient, _royaltyBps, ""))
        );
        vm.expectRevert();
        IERC721(_ERC721).mint(
            address(this), abi.encode(bytes32("foobar"), abi.encode(_royaltyRecipient, _royaltyBps, ""))
        );
    }

    function _testFailBurnUnminted(address _ERC721) internal {
        vm.expectRevert();
        IERC721LazyMint(_ERC721).burn(1);
    }

    function _testFailDoubleBurn(address _ERC721) internal {
        IERC721LazyMint(_ERC721).burn(0);
        vm.expectRevert();
        IERC721LazyMint(_ERC721).burn(0);
    }

    function _testFailApproveUnMinted(address _ERC721) internal {
        vm.expectRevert();
        IERC721(_ERC721).approve(address(0xABCD), 1337);
    }

    function _testFailApproveUnAuthorized(address _ERC721) internal {
        vm.expectRevert();
        vm.prank(address(1337));
        IERC721(_ERC721).approve(address(0xABCD), 0);
    }

    function _testFailTransferFromUnOwned(address _ERC721) internal {
        vm.expectRevert();
        vm.prank(address(1337));
        IERC721(_ERC721).transferFrom(address(1337), address(this), 1337);
    }

    function _testFailTransferFromWrongFrom(address _ERC721) internal {
        vm.expectRevert();
        IERC721(_ERC721).transferFrom(address(1337), address(this), 0);
    }

    function _testFailTransferFromToZero(address _ERC721) internal {
        vm.expectRevert();
        IERC721(_ERC721).transferFrom(address(this), address(0), 0);
    }

    function _testFailTransferFromNotOwner(address _ERC721) internal {
        vm.expectRevert();
        vm.prank(address(1337));
        IERC721(_ERC721).transferFrom(address(this), address(1337), 0);
    }

    function _testFailSafeTransferFromToNonERC721Recipient(address _ERC721) internal {
        address nonERC721Recipient = address(new NonERC721Recipient());
        vm.expectRevert();
        IERC721(_ERC721).safeTransferFrom(address(this), nonERC721Recipient, 0);
    }

    function _testFailSafeTransferFromToNonERC721RecipientWithData(address _ERC721) internal {
        address nonERC721Recipient = address(new NonERC721Recipient());
        vm.expectRevert();
        IERC721(_ERC721).safeTransferFrom(address(this), nonERC721Recipient, 0, "testing 123");
    }

    function _testFailSafeTransferFromToRevertingERC721Recipient(address _ERC721) internal {
        address revertingERC721Recipient = address(new RevertingERC721Recipient());
        vm.expectRevert();
        IERC721(_ERC721).safeTransferFrom(address(this), revertingERC721Recipient, 0);
    }

    function _testFailSafeTransferFromToRevertingERC721RecipientWithData(address _ERC721) internal {
        address revertingERC721Recipient = address(new RevertingERC721Recipient());
        vm.expectRevert();
        IERC721(_ERC721).safeTransferFrom(address(this), revertingERC721Recipient, 0, "testing 123");
    }

    function _testFailSafeTransferFromToERC721RecipientWithWrongReturnData(address _ERC721) internal {
        address wrongReturnDataERC721Recipient = address(new WrongReturnDataERC721Recipient());
        vm.expectRevert();
        IERC721(_ERC721).safeTransferFrom(address(this), wrongReturnDataERC721Recipient, 0);
    }

    function _testFailSafeTransferFromToERC721RecipientWithWrongReturnDataWithData(address _ERC721) internal {
        address wrongReturnDataERC721Recipient = address(new WrongReturnDataERC721Recipient());
        vm.expectRevert();
        IERC721(_ERC721).safeTransferFrom(address(this), wrongReturnDataERC721Recipient, 0, "testing 123");
    }

    function _testFailSafeMintToNonERC721Recipient(
        address _ERC721,
        address _royaltyRecipient,
        uint96 _royaltyBps
    )
        internal
    {
        address _nonERC721Recipient = address(new NonERC721Recipient());
        vm.expectRevert();
        IERC721(_ERC721).mint(
            _nonERC721Recipient, abi.encode(bytes32("foobar"), abi.encode(_royaltyRecipient, _royaltyBps, ""))
        );
    }

    function _testFailSafeMintToNonERC721RecipientWithData(
        address _ERC721,
        address _royaltyRecipient,
        uint96 _royaltyBps
    )
        internal
    {
        address _nonERC721Recipient = address(new NonERC721Recipient());
        vm.expectRevert();
        IERC721(_ERC721).mint(
            _nonERC721Recipient,
            abi.encode(bytes32("foobar"), abi.encode(_royaltyRecipient, _royaltyBps, "testing 123"))
        );
    }

    function _testFailSafeMintToRevertingERC721Recipient(
        address _ERC721,
        address _royaltyRecipient,
        uint96 _royaltyBps
    )
        internal
    {
        address revertingERC721Recipient = address(new RevertingERC721Recipient());
        vm.expectRevert();
        IERC721(_ERC721).mint(
            revertingERC721Recipient, abi.encode(bytes32("foobar"), abi.encode(_royaltyRecipient, _royaltyBps, ""))
        );
    }

    function _testFailSafeMintToRevertingERC721RecipientWithData(
        address _ERC721,
        address _royaltyRecipient,
        uint96 _royaltyBps
    )
        internal
    {
        address revertingERC721Recipient = address(new RevertingERC721Recipient());
        vm.expectRevert();
        IERC721(_ERC721).mint(
            revertingERC721Recipient,
            abi.encode(bytes32("foobar"), abi.encode(_royaltyRecipient, _royaltyBps, "testing 123"))
        );
    }

    function _testFailSafeMintToERC721RecipientWithWrongReturnData(
        address _ERC721,
        address _royaltyRecipient,
        uint96 _royaltyBps
    )
        internal
    {
        address _wrongReturnDataERC721Recipient = address(new WrongReturnDataERC721Recipient());
        vm.expectRevert();
        IERC721(_ERC721).mint(
            _wrongReturnDataERC721Recipient,
            abi.encode(bytes32("foobar"), abi.encode(_royaltyRecipient, _royaltyBps, ""))
        );
    }

    function _testFailSafeMintToERC721RecipientWithWrongReturnDataWithData(
        address _ERC721,
        address _royaltyRecipient,
        uint96 _royaltyBps
    )
        internal
    {
        address _wrongReturnDataERC721Recipient = address(new WrongReturnDataERC721Recipient());
        vm.expectRevert();
        IERC721(_ERC721).mint(
            _wrongReturnDataERC721Recipient,
            abi.encode(bytes32("foobar"), abi.encode(_royaltyRecipient, _royaltyBps, "testing 123"))
        );
    }

    /// @dev balanceOf(address(0)) should throw.
    function _testFailBalanceOfZeroAddress(address _ERC721) internal {
        vm.expectRevert();
        IERC721(_ERC721).balanceOf(address(0));
    }

    function _testFailOwnerOfUnminted(address _ERC721) internal {
        vm.expectRevert();
        IERC721(_ERC721).ownerOf(1);
    }

    /*----------------------------------------------------------*|
    |*  # LAZY MINT AND LAZY BUY                                *|
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

    // test lazy mint from testing contract signing via ERC1271, sovereign contracts must support this ERC!
    // function _testLazyMintFromERC1271Signer {
    //     // TODO
    // }

    // TODO test private sale lazy mint
    // todo test royalties; a) default royalties (none set when minting), b) set royalty info with an array length of 1
    // and c) 2 recipients (multiple recipients)
    function _testLazyMint(
        address _ERC721,
        address _artist,
        address _collector,
        address[] memory _commissionRecipients,
        uint96[] memory _commissionBps,
        uint96 _royaltyBps,
        uint256 _PK,
        uint256 _unitPrice,
        bool _expectRevert
    )
        internal
    {
        uint256 tokenId = IERC721Enumerable(_ERC721).totalSupply();

        EncodeType.TokenVoucher memory voucher = EncodeType.TokenVoucher(
            bytes32("foobar"), // tokenURI
            _unitPrice, // price
            type(uint32).max, // endTime
            0, // tokenid - not used in lazy mint
            0, // ERC1155Value
            block.timestamp, // salt
            address(0), // whitelisted buyer
            address(0), // ERC1271Account
            _artist, // royaltyRecipient
            _royaltyBps,
            _commissionBps,
            _commissionRecipients
        );

        ( /*bytes32 digest*/ , bytes memory signature) = _getDigestAndSignature(_ERC721, voucher, _PK);

        uint256 buyerBalance = _collector.balance;
        uint256 artistBalance = _artist.balance;
        uint256 primarySaleCommissionAmount;

        if (_commissionBps.length > 0) {
            primarySaleCommissionAmount = _unitPrice * _commissionBps[0] / 10_000;
        }

        if (_expectRevert) vm.expectRevert();
        vm.prank(_collector);
        IERC721LazyMint(_ERC721).lazyMint{ value: _unitPrice }(voucher, signature, "", _collector);

        // no need to check assertions if we expect a revert
        if (_expectRevert) return;
        // check ownership
        assertEq(IERC721(_ERC721).balanceOf(_collector), 1, "EOA balance incorrect");
        assertEq(IERC721(_ERC721).ownerOf(tokenId), _collector, "ownerOf failed");
        // check balances
        assertEq(_collector.balance, buyerBalance - _unitPrice, "buyer balance failed");
        assertEq(
            _artist.balance,
            artistBalance + _unitPrice - primarySaleCommissionAmount,
            "lazy mint, artist balance failed"
        );
        if (primarySaleCommissionAmount > 0) {
            assertEq(_commissionRecipients[0].balance, primarySaleCommissionAmount, "_feesRecipient balance failed");
        }
    }

    function _testLazyBuy(
        address _ERC721,
        address _seller,
        address _buyer,
        address _feesRecipient,
        EncodeType.TokenVoucher memory _voucher,
        bytes memory _signature,
        bool _expectRevert
    )
        internal
    {
        uint256 buyerBalance = _buyer.balance;
        uint256 sellerBalance = _seller.balance;
        uint256 feeAmount;
        address royaltyRecipient;
        uint256 royaltyRecipientBalance;
        uint256 royaltyAmount;
        // uint256 tokenId;

        if (_voucher.commissionBps.length > 0) {
            feeAmount = _voucher.price * _voucher.commissionBps[0] / 10_000;
        }

        (royaltyRecipient, royaltyAmount) = IERC721LazyMint(_ERC721).royaltyInfo(_voucher.tokenId, _voucher.price);
        royaltyRecipientBalance = royaltyRecipient.balance;

        if (_expectRevert) vm.expectRevert();
        vm.prank(_buyer);
        IERC721LazyMint(_ERC721).lazyBuy{ value: _voucher.price }(_voucher, _signature, "", _buyer);

        // no need to check assertions if we expect a revert
        if (_expectRevert) return;

        // check ownership
        assertEq(IERC721(_ERC721).balanceOf(_buyer), 1, "EOA balance incorrect");
        assertEq(IERC721(_ERC721).ownerOf(_voucher.tokenId), _buyer, "ownerOf failed");
        // check balances
        assertEq(_buyer.balance, buyerBalance - _voucher.price, "collector balance failed");

        assertEq(
            _seller.balance,
            sellerBalance + _voucher.price - feeAmount - royaltyAmount,
            "lazy buy, seller balance failed"
        ); // checking this contract's balance because it is the one that receives the funds, i.e. token was not lazy
            // minted hence owner is contract
        if (feeAmount > 0) {
            assertEq(_feesRecipient.balance, feeAmount, "_feesRecipient balance failed");
        }
        assertEq(royaltyRecipient.balance, royaltyRecipientBalance + royaltyAmount, "royaltyRecipient balance failed");
    }

    function _testVoidVoucher(
        address _ERC721,
        address _artist,
        address[] memory _commissionRecipients,
        uint96[] memory _commissionBps,
        uint96 _royaltyBps,
        uint256 _PK,
        uint256 _unitPrice
    )
        internal
    {
        //uint256 tokenId;
        //tokenId = IERC721Enumerable(_ERC721).totalSupply();

        EncodeType.TokenVoucher memory voucher = EncodeType.TokenVoucher(
            bytes32("foobar"), // tokenURI
            _unitPrice, // price
            type(uint32).max, // endTime
            0, // tokenid
            0, // ERC1155Value
            block.timestamp, // salt
            address(0), // whitelisted buyer
            address(0), // ERC1271Account
            _artist, // royaltyRecipient
            _royaltyBps,
            _commissionBps,
            _commissionRecipients
        );

        (bytes32 digest,) = _getDigestAndSignature(_ERC721, voucher, _PK);

        bytes32[] memory digests = new bytes32[](1);
        digests[0] = digest;

        vm.prank(_artist); // prank PK account
        IERC721LazyMint(_ERC721).voidVouchers(digests);
    }
}
