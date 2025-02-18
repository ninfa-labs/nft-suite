// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @notice Struct needed for endodeType and encodeData, see
 * https://eips.ethereum.org/EIPS/eip-712#definition-of-encodetype
 */
library EncodeType {
    /**
     * @param tokenURI the IPFS hash of the metadata
     * @param tokenId the id of the token to sell
     * @param endTime salt for when the signed voucher should expire,
     *      if no expiration is needed, salt should be `type(uint256).max`
     * i.e. 2**256 - 1,
     *      or anything above 2^32, i.e. 4294967296, i.e. voucher expires after
     * 2106 (in 83 years time)
     * @param salt salt for the signature, to prevent replay attacks,
     * also because it is the only way to make the same voucher unique,
     * or else it would not be possible to sign the same encodeData twice because the signature is voided after lazyBuy
     * is executed
     * The voucher is not voided after lazyMint because it is not supposed to be used more than once; enforced in
     * `ERC721Metadata_URI-_mint()` to avoid repolay attacks
     * @param buyer if not empty, indicates that the voucher is for a specific address
     * @param ERC1271Account if not empty, indicates that the signer is a contract that implements ERC1271
     * @param tokenId the tokenId will be ignored in lazyMint, because it will be _owners.length
     * while it must beused in lazyBuy
     * @param royaltyBps royalty basis points. Will be ignored in lazyBuy, while it must be used in lazyMint
     * @param royaltyRecipients royalty recipient. Will be ignored in lazyBuy, while it must be used in lazyMint
     * @param commissionBps array of commission basis points, i.e. 10000 = 100%,
     *     commissionBps.length must be the same as commissionRecipients.length
     * @param commissionRecipients array of commission recipients
     */
    struct TokenVoucher {
        bytes32 tokenURI;
        uint256 price;
        uint256 endTime;
        uint256 tokenId;
        uint256 ERC1155Value;
        uint256 salt;
        address buyer;
        address ERC1271Account;
        address royaltyRecipient;
        uint96 royaltyBps;
        uint96[] commissionBps;
        address[] commissionRecipients;
    }

    /**
     * @param endTime salt for when the signed voucher should expire,
     *      if no expiration is needed, salt should be `type(uint256).max`
     * i.e. 2**256 - 1,
     *      or anything above 2^32, i.e. 4294967296, i.e. voucher expires after
     * 2106 (in 83 years time)
     * @param salt salt for the signature, to prevent replay attacks,
     * also because it is the only way to make the same voucher unique,
     * or else it would not be possible to sign the same encodeData twice because the signature is voided after lazyBuy
     * is executed
     * The voucher is not voided after lazyMint because it is not supposed to be used more than once; enforced in
     * `ERC721Metadata_URI-_mint()` to avoid repolay attacks
     * @param buyer if not empty, indicates that the voucher is for a specific address, and that the voucher
     * @param ERC1271Account if not empty, indicates that the signer is a contract that implements ERC1271
     * @param tokenId the tokenId will be ignored in lazyMint, because it will be _owners.length
     * while it must beused in lazyBuy
     * @param royaltyBps royalty basis points. Will be ignored in lazyBuy, while it must be used in lazyMint
     * @param royaltyReceivers royalty recipient. Will be ignored in lazyBuy, while it must be used in lazyMint
     * @param commissionBps array of commission basis points, i.e. 10000 = 100%,
     *     commissionBps.length must be the same as commissionReceivers.length
     * @param commissionReceivers array of commission receivers
     */
    struct MarketplaceVoucher {
        uint256 price;
        uint256 endTime;
        uint256 tokenId;
        uint256 ERC1155Value;
        uint256 salt;
        address collection;
        address buyer;
        address ERC1271Account;
        uint96[] commissionBps;
        address[] commissionReceivers;
    }
}
