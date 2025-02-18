// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console2 } from "forge-std/console2.sol";
import "src/token/ERC721/presets/ERC721LazyMint.sol";
import "src/token/ERC721/presets/ERC721Base.sol";
import { IERC721 } from "test/interfaces/IERC721.sol";
import "test/utils/Setup.sol";
import "src/factory/CuratedFactory.sol";
import "src/EnglishAuction.sol";

contract NinfaAuctionTest is Setup {
    ERC721Base private _ERC721LazyMintMaster;
    ERC721Base private _ERC721BaseClone;

    EnglishAuction private _ninfaEnglishAuction;

    address private _ERC721BaseCloneAddress;

    function setUp() public {
        /*------------------------------------------------------------*|
      |*  # NINFA English Auction                                   *|
      |*------------------------------------------------------------*/

        _ninfaEnglishAuction = new EnglishAuction(_FEES_RECIPIENT, _FEE_BPS);

        _CURATED_FACTORY.grantRole(_MINTER_ROLE, _MINTER);

        bytes32 salt = bytes32(0);

        _ERC721BaseCloneAddress =
            _CURATED_FACTORY.clone(address(_ERC721_BASE_MASTER), salt, abi.encode(_MINTER, 1000, _SYMBOL, _NAME));
        _ERC721BaseClone = ERC721Base(_ERC721BaseCloneAddress);
        _ERC721BaseClone.mint(_MINTER, abi.encode(_TOKEN_URI, abi.encode(_MINTER, _ROYALTY_BPS, "")));

        assertEq(_ERC721BaseClone.balanceOf(_MINTER), 1);
        assertEq(_ERC721BaseClone.ownerOf(0), _MINTER);

        uint24[] memory recipientBpsArray = new uint24[](1);
        recipientBpsArray[0] = 10_000;

        address[] memory royaltyRecipients = new address[](1);
        royaltyRecipients[0] = _MINTER;

        vm.deal(_COLLECTOR_PRIMARY, _STARTING_BALANCE);
        vm.deal(_COLLECTOR_SECONDARY, _STARTING_BALANCE);
    }

    function testCreateAuction() public {
        uint256 price = 10_000;
        _createAuction(0, address(_ERC721BaseClone), price, _MINTER, 1);
    }

    function testCreateAuctionWithCommissions() public {
        uint256 price = 10_000;
        _createAuctionWithCommissions(0, address(_ERC721BaseClone), price, _MINTER, 1);
    }

    function testEditAndCancelAuction() public {
        uint256 price = 10_000;
        uint256 newPrice = 20_000;
        _createAuction(0, address(_ERC721BaseClone), price, _MINTER, 1);

        vm.prank(_MINTER);
        _ninfaEnglishAuction.updateReservePrice(1, newPrice);

        EnglishAuction.Auction memory auction = _ninfaEnglishAuction.getAuction(1);

        assertEq(auction.operator, _MINTER);
        assertEq(auction.seller, _MINTER);
        assertEq(auction.collection, address(_ERC721BaseClone));
        assertEq(auction.bidder, address(0));
        assertEq(auction.commissionReceivers.length, 0);
        assertEq(auction.commissionBps.length, 0);
        assertEq(auction.tokenId, 0);
        assertEq(auction.bidPrice, newPrice);
        assertEq(auction.end, 0);

        vm.prank(_MINTER);
        _ninfaEnglishAuction.cancelAuction(1);

        auction = _ninfaEnglishAuction.getAuction(1);

        assertEq(auction.operator, address(0));
        assertEq(auction.seller, address(0));
        assertEq(auction.collection, address(0));
        assertEq(auction.bidder, address(0));
        assertEq(auction.commissionReceivers.length, 0);
        assertEq(auction.commissionBps.length, 0);
        assertEq(auction.tokenId, 0);
        assertEq(auction.bidPrice, 0);
        assertEq(auction.end, 0);
    }

    function testFirstBid() public {
        uint256 price = 10_000;
        _createAuction(0, address(_ERC721BaseClone), price, _MINTER, 1);

        vm.prank(_COLLECTOR_PRIMARY);
        _ninfaEnglishAuction.firstBid{ value: price }(1, _COLLECTOR_PRIMARY);

        EnglishAuction.Auction memory auction = _ninfaEnglishAuction.getAuction(1);

        assertEq(auction.operator, _MINTER);
        assertEq(auction.seller, _MINTER);
        assertEq(auction.collection, address(_ERC721BaseClone));
        assertEq(auction.bidder, _COLLECTOR_PRIMARY);
        assertEq(auction.commissionReceivers.length, 0);
        assertEq(auction.commissionBps.length, 0);
        assertEq(auction.tokenId, 0);
        assertEq(auction.bidPrice, price);
        assertEq(auction.end, block.timestamp + 1 days);

        assertEq(_COLLECTOR_PRIMARY.balance, _STARTING_BALANCE - price);
    }

    function testSecondBid() public {
        uint256 price = 10_000;
        uint256 secondPrice = 10_500;
        _createAuction(0, address(_ERC721BaseClone), price, _MINTER, 1);

        vm.prank(_COLLECTOR_PRIMARY);
        _ninfaEnglishAuction.firstBid{ value: price }(1, _COLLECTOR_PRIMARY);

        vm.prank(_COLLECTOR_SECONDARY);
        _ninfaEnglishAuction.bid{ value: secondPrice }(1, _COLLECTOR_SECONDARY);

        EnglishAuction.Auction memory auction = _ninfaEnglishAuction.getAuction(1);

        assertEq(auction.operator, _MINTER);
        assertEq(auction.seller, _MINTER);
        assertEq(auction.collection, address(_ERC721BaseClone));
        assertEq(auction.bidder, _COLLECTOR_SECONDARY);
        assertEq(auction.commissionReceivers.length, 0);
        assertEq(auction.commissionBps.length, 0);
        assertEq(auction.tokenId, 0);
        assertEq(auction.bidPrice, secondPrice);
        assertEq(auction.end, block.timestamp + 1 days);

        assertEq(_COLLECTOR_PRIMARY.balance, _STARTING_BALANCE);
        assertEq(_COLLECTOR_SECONDARY.balance, _STARTING_BALANCE - secondPrice);
    }

    function test_RevertWhen_SecondBidTooLow() public {
        uint256 price = 10_000;
        // second bid shoud be at least 5% higher than the first one
        uint256 secondPrice = 10_400;
        _createAuction(0, address(_ERC721BaseClone), price, _MINTER, 1);

        vm.prank(_COLLECTOR_PRIMARY);
        _ninfaEnglishAuction.firstBid{ value: price }(1, _COLLECTOR_PRIMARY);

        vm.expectRevert();
        vm.prank(_COLLECTOR_SECONDARY);
        _ninfaEnglishAuction.bid{ value: secondPrice }(1, _COLLECTOR_SECONDARY);
    }

    function test_RevertWhen_EditAuctionAfterBid() public {
        uint256 price = 10_000;
        uint256 newPrice = 20_000;
        _createAuction(0, address(_ERC721BaseClone), price, _MINTER, 1);

        vm.prank(_COLLECTOR_PRIMARY);
        _ninfaEnglishAuction.firstBid{ value: price }(1, _COLLECTOR_PRIMARY);

        vm.expectRevert();
        vm.prank(_MINTER);
        _ninfaEnglishAuction.updateReservePrice(1, newPrice);
    }

    function test_RevertWhen_CancelAuctionAfterBid() public {
        uint256 price = 10_000;
        _createAuction(0, address(_ERC721BaseClone), price, _MINTER, 1);

        vm.prank(_COLLECTOR_PRIMARY);
        _ninfaEnglishAuction.firstBid{ value: price }(1, _COLLECTOR_PRIMARY);

        vm.expectRevert();
        vm.prank(_MINTER);
        _ninfaEnglishAuction.cancelAuction(1);
    }

    function testBidWithinExtensionTime() public {
        uint256 price = 10_000;
        uint256 secondPrice = 10_500;
        _createAuction(0, address(_ERC721BaseClone), price, _MINTER, 1);

        vm.prank(_COLLECTOR_PRIMARY);
        _ninfaEnglishAuction.firstBid{ value: price }(1, _COLLECTOR_PRIMARY);

        EnglishAuction.Auction memory oldAuction = _ninfaEnglishAuction.getAuction(1);

        vm.warp(block.timestamp + 1 days - 14 minutes);

        vm.prank(_COLLECTOR_SECONDARY);
        _ninfaEnglishAuction.bid{ value: secondPrice }(1, _COLLECTOR_SECONDARY);

        EnglishAuction.Auction memory auction = _ninfaEnglishAuction.getAuction(1);

        assertEq(auction.operator, _MINTER);
        assertEq(auction.seller, _MINTER);
        assertEq(auction.collection, address(_ERC721BaseClone));
        assertEq(auction.bidder, _COLLECTOR_SECONDARY);
        assertEq(auction.commissionReceivers.length, 0);
        assertEq(auction.commissionBps.length, 0);
        assertEq(auction.tokenId, 0);
        assertEq(auction.bidPrice, secondPrice);
        assertEq(auction.end, oldAuction.end + 15 minutes);

        assertEq(_COLLECTOR_PRIMARY.balance, _STARTING_BALANCE);
        assertEq(_COLLECTOR_SECONDARY.balance, _STARTING_BALANCE - secondPrice);
    }

    function test_RevertWhen_BidAfterAuctionEnded() public {
        uint256 price = 10_000;
        uint256 secondPrice = 10_500;
        _createAuction(0, address(_ERC721BaseClone), price, _MINTER, 1);

        vm.prank(_COLLECTOR_PRIMARY);
        _ninfaEnglishAuction.firstBid{ value: price }(1, _COLLECTOR_PRIMARY);

        vm.warp(block.timestamp + 1 days + 1 minutes);

        vm.expectRevert();
        vm.prank(_COLLECTOR_SECONDARY);
        _ninfaEnglishAuction.bid{ value: secondPrice }(1, _COLLECTOR_SECONDARY);
    }

    function testFinalizeAuction() public {
        uint256 price = 10_000;
        _createAuction(0, address(_ERC721BaseClone), price, _MINTER, 1);

        //uint256 oldMinterBalance = _MINTER.balance;

        vm.prank(_COLLECTOR_PRIMARY);
        _ninfaEnglishAuction.firstBid{ value: price }(1, _COLLECTOR_PRIMARY);

        vm.warp(block.timestamp + 1 days + 1 minutes);

        vm.prank(_COLLECTOR_PRIMARY);
        _ninfaEnglishAuction.finalize(1);

        assertEq(_COLLECTOR_PRIMARY.balance, _STARTING_BALANCE - price, "_COLLECTOR_PRIMARY balance not correct");

        // assertEq(_MINTER.balance - oldMinterBalance, price * (_TOTAL_BPS - _FEE_BPS) / _TOTAL_BPS, "_MINTER balance
        // not correct");
        assertEq(_FEES_RECIPIENT.balance, price * (_FEE_BPS) / _TOTAL_BPS, "fee account balance not correct");

        assertEq(_ERC721BaseClone.balanceOf(_COLLECTOR_PRIMARY), 1, "balance of collector should be 1");
        assertEq(
            _ERC721BaseClone.balanceOf(address(_ninfaEnglishAuction)), 0, "balance of ninfaMarketplace should be 0"
        );
        assertEq(_ERC721BaseClone.balanceOf(_MINTER), 0, "balance of _MINTER should be 0");
        assertEq(_ERC721BaseClone.ownerOf(0), _COLLECTOR_PRIMARY, "owner of token should be _COLLECTOR_PRIMARY");
    }

    function test_RevertWhen_FinalizeAuctionBeforeEnd() public {
        uint256 price = 10_000;
        _createAuction(0, address(_ERC721BaseClone), price, _MINTER, 1);

        vm.prank(_COLLECTOR_PRIMARY);
        _ninfaEnglishAuction.firstBid{ value: price }(1, _COLLECTOR_PRIMARY);

        vm.expectRevert();
        _ninfaEnglishAuction.finalize(1);
    }

    function testFinalizeAuctionSecondary() public {
        uint256 price = 10_000;
        uint256 roylaties = 1000;
        _createAuction(0, address(_ERC721BaseClone), price, _MINTER, 1);

        vm.prank(_COLLECTOR_PRIMARY);
        _ninfaEnglishAuction.firstBid{ value: price }(1, _COLLECTOR_PRIMARY);

        vm.warp(block.timestamp + 1 days + 1 minutes);

        _ninfaEnglishAuction.finalize(1);

        uint256 collectorBalanceBeforeSecondary = _COLLECTOR_PRIMARY.balance;
        uint256 multisigBalanceBeforeSecondary = _FEES_RECIPIENT.balance;
        uint256 minterBalanceBeforeSecondary = _MINTER.balance;

        _createAuction(0, address(_ERC721BaseClone), price, _COLLECTOR_PRIMARY, 2);

        vm.prank(_COLLECTOR_SECONDARY);
        _ninfaEnglishAuction.firstBid{ value: price }(2, _COLLECTOR_SECONDARY);

        vm.warp(block.timestamp + 1 days + 1 minutes);

        _ninfaEnglishAuction.finalize(2);

        assertEq(_COLLECTOR_SECONDARY.balance, _STARTING_BALANCE - price, "_COLLECTOR_SECONDARY balance not correct");
        assertEq(
            _COLLECTOR_PRIMARY.balance,
            collectorBalanceBeforeSecondary + price * (_TOTAL_BPS - _FEE_BPS - roylaties) / _TOTAL_BPS,
            "_COLLECTOR_PRIMARY balance not correct"
        );
        assertEq(
            _MINTER.balance,
            minterBalanceBeforeSecondary + price * roylaties / _TOTAL_BPS,
            "_MINTER balance not correct"
        );
        assertEq(
            _FEES_RECIPIENT.balance,
            multisigBalanceBeforeSecondary + price * (_FEE_BPS) / _TOTAL_BPS,
            "fee account balance not correct"
        );

        assertEq(_ERC721BaseClone.balanceOf(_COLLECTOR_SECONDARY), 1, "balance of _COLLECTOR_SECONDARY should be 1");
        assertEq(
            _ERC721BaseClone.balanceOf(address(_ninfaEnglishAuction)), 0, "balance of ninfaMarketplace should be 0"
        );
        assertEq(_ERC721BaseClone.balanceOf(_COLLECTOR_PRIMARY), 0, "balance of _COLLECTOR_PRIMARY should be 0");
        assertEq(_ERC721BaseClone.ownerOf(0), _COLLECTOR_SECONDARY, "owner of token should be _COLLECTOR_SECONDARY");
    }

    function _createAuction(
        uint256 tokenId,
        address collection,
        uint256 price,
        address seller,
        uint256 auctionId
    )
        private
    {
        vm.startPrank(seller);
        uint256[] memory commissionBps = new uint256[](0);
        address[] memory commissionReceivers = new address[](0);
        bytes memory _data = abi.encode(price, commissionBps, commissionReceivers);
        IERC721(collection).safeTransferFrom(seller, address(_ninfaEnglishAuction), tokenId, _data);
        vm.stopPrank();

        EnglishAuction.Auction memory auction = _ninfaEnglishAuction.getAuction(auctionId);

        assertEq(IERC721(collection).balanceOf(address(_ninfaEnglishAuction)), 1);
        assertEq(IERC721(collection).ownerOf(tokenId), address(_ninfaEnglishAuction));
        assertEq(IERC721(collection).balanceOf(seller), 0);
        assertEq(auction.operator, seller);
        assertEq(auction.seller, seller);
        assertEq(auction.collection, collection);
        assertEq(auction.bidder, address(0));
        assertEq(auction.commissionReceivers, commissionReceivers);
        assertEq(auction.commissionBps, commissionBps);
        assertEq(auction.tokenId, tokenId);
        assertEq(auction.bidPrice, price);
        assertEq(auction.end, 0);
    }

    function _createAuctionWithCommissions(
        uint256 tokenId,
        address collection,
        uint256 price,
        address seller,
        uint256 auctionId
    )
        private
    {
        vm.startPrank(seller);
        uint256[] memory commissionBps = new uint256[](1);
        commissionBps[0] = 1000;
        address[] memory commissionReceivers = new address[](1);
        commissionReceivers[0] = _ANON;
        bytes memory _data = abi.encode(price, commissionBps, commissionReceivers);
        IERC721(collection).safeTransferFrom(seller, address(_ninfaEnglishAuction), tokenId, _data);

        EnglishAuction.Auction memory auction = _ninfaEnglishAuction.getAuction(auctionId);

        vm.stopPrank();
        assertEq(IERC721(collection).balanceOf(address(_ninfaEnglishAuction)), 1);
        assertEq(IERC721(collection).ownerOf(tokenId), address(_ninfaEnglishAuction));
        assertEq(IERC721(collection).balanceOf(seller), 0);
        assertEq(auction.operator, seller);
        assertEq(auction.seller, seller);
        assertEq(auction.collection, collection);
        assertEq(auction.bidder, address(0));
        assertEq(auction.commissionReceivers, commissionReceivers);
        assertEq(auction.commissionBps, commissionBps);
        assertEq(auction.tokenId, tokenId);
        assertEq(auction.bidPrice, price);
        assertEq(auction.end, 0);
    }

    receive() external payable { }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure returns (bytes4) {
        return 0xf23a6e61;
    }

    function onERC721Received(address, address, uint256, bytes calldata) public pure returns (bytes4) {
        return 0x150b7a02; // ERC721TokenReceiver.onERC721Received.selector;
    }
}
