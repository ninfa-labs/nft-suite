// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./interfaces/IManifold.sol";
import "./interfaces/IRarible.sol";
import "./interfaces/IFoundation.sol";
import "./interfaces/ISuperRare.sol";
import "./interfaces/IEIP2981.sol";
import "./interfaces/IZoraOverride.sol";
import "./interfaces/IArtBlocksOverride.sol";
import "./interfaces/IKODAV2Override.sol";

/**
 *
 * @title RoyaltyEngineV1                                    *
 *                                                           *
 * @notice Custom implementation of Manifold RoyaltyEngineV1 *
 *                                                           *
 * @dev > "Marketplaces may choose to directly inherit the   *
 * Royalty Engine to save a bit of gas".                     *
 *                                                           *
 * @dev ERC165 was removed because interface selector will   *
 * be different from Manifold's (0xcb23f816) and this engine *
 * implementation is not meant for used by other contracts   *
 *
 * @dev the original RoyaltyEngineV1 has been modified by removing the
 * _specCache and the associated code,
 * using try catch statements is very cheap, no need to store `_specCache`
 * mapping, see
 * {RoyaltyEngineV1-_specCache}.
 * - https://www.reddit.com/r/ethdev/comments/szot8r/comment/hy5vsxb/
 *                                                           *
 * @author Ninfa's fork of Manifold's RoyaltyRegistryV1      *
 *                                                           *
 * @custom:security-contact tech@ninfa.io                    *
 *
 */
contract RoyaltyEngineV1 {
    address internal constant SUPERRARE_REGISTRY = 0x17B0C8564E53f22364A6C8de6F7ca5CE9BEa4e5D;
    address internal constant SUPERRARE_V1 = 0x41A322b28D0fF354040e2CbC676F0320d8c8850d;
    address internal constant SUPERRARE_V2 = 0xb932a70A57673d89f4acfFBE830E8ed7f75Fb9e0;

    error Unauthorized();
    error InvalidAmount(uint256 amount);
    error LengthMismatch(uint256 recipients, uint256 bps); // only used in
        // RoyaltyEngineV1

    /**
     * Get the royalties for a given token and sale amount.
     *
     * @param tokenAddress - address of token
     * @param tokenId - id of token
     * @param value - sale value of token
     * Returns two arrays, first is the list of royalty recipients, second is
     * the amounts for each recipient.
     */
    function getRoyalty(
        address tokenAddress,
        uint256 tokenId,
        uint256 value
    )
        internal
        view
        returns (address payable[] memory recipients, uint256[] memory amounts)
    {
        /**
         * @dev Control-flow hijack and gas griefing vulnerability within
         * Manifold's RoyaltyEngine, mitigated in
         * https://github.com/manifoldxyz/royalty-registry-solidity/commit/c5ba6db3e04e0b364f7afd7aae853a25542a7439.
         *      "To mitigate the griefing vector and other potential
         * vulnerabilities, limit the gas by default that
         * _getRoyalty is given to at most 50,000 gas, but certainly no more
         * than 100,000 gas."
         *      -
         * https://githubrecord.com/issue/manifoldxyz/royalty-registry-solidity/17/1067105243
         *      However, Ninfa's ERC-2981 implementation (ERC2981N) needs to write to
         * storage upon primary sales, this consumes
         * 800,000 at most gas,
         *      while it only reads from storage upon secondary sales, see
         * {ERC2981N-rotaltyInfo}
         */
        try this._getRoyalty{ gas: 1_000_000 }(tokenAddress, tokenId, value) returns (
            address payable[] memory _recipients, uint256[] memory _amounts
        ) {
            return (_recipients, _amounts);
        } catch {
            revert("Royalty lookup failed");
        }
    }

    /**
     * @dev Get the royalty for a given token
     * @dev the original RoyaltyEngineV1 has been modified by removing the
     * _specCache and the associated code,
     * using try catch statements is very cheap, no need to store `_specCache`
     * mapping, see
     * {RoyaltyEngineV1-_specCache}.
     * - https://www.reddit.com/r/ethdev/comments/szot8r/comment/hy5vsxb/
     * @dev EIP-2981 standard lookup is performed first unlike Manifold's
     * implementation, as it is the most prevalent
     * royalty standard as well as the one being used by Ninfa's collections
     * @return recipients array and amounts array, if no royalty standard has
     * been found, the returned arrays will be
     * empty
     */
    function _getRoyalty(
        address tokenAddress,
        uint256 tokenId,
        uint256 value
    )
        external
        view
        returns (address payable[] memory recipients, uint256[] memory amounts)
    {
        try IEIP2981(tokenAddress).royaltyInfo(tokenId, value) returns (address recipient, uint256 amount) {
            if (amount > value) revert InvalidAmount(amount);
            // Supports EIP2981. Return amounts
            recipients = new address payable[](1);
            amounts = new uint256[](1);
            recipients[0] = payable(recipient);
            amounts[0] = amount;

            return (recipients, amounts);
        } catch { }

        try IManifold(tokenAddress).getRoyalties(tokenId) returns (
            address payable[] memory recipients_, uint256[] memory bps
        ) {
            // Supports manifold interface.  Compute amounts
            require(recipients_.length == bps.length);
            return (recipients_, _computeAmounts(value, bps));
        } catch { }

        // SuperRare handling
        if (tokenAddress == SUPERRARE_V1 || tokenAddress == SUPERRARE_V2) {
            try ISuperRareRegistry(SUPERRARE_REGISTRY).tokenCreator(tokenAddress, tokenId) returns (
                address payable creator
            ) {
                try ISuperRareRegistry(SUPERRARE_REGISTRY).calculateRoyaltyFee(tokenAddress, tokenId, value) returns (
                    uint256 amount
                ) {
                    recipients = new address payable[](1);
                    amounts = new uint256[](1);
                    recipients[0] = creator;
                    amounts[0] = amount;
                    return (recipients, amounts);
                } catch { }
            } catch { }
        }

        try IFoundation(tokenAddress).getFees(tokenId) returns (
            address payable[] memory recipients_, uint256[] memory bps
        ) {
            // Supports foundation interface.  Compute amounts
            if (recipients_.length != bps.length) {
                revert LengthMismatch(recipients_.length, bps.length);
            }
            return (recipients_, _computeAmounts(value, bps));
        } catch { }

        try IRaribleV2(tokenAddress).getRaribleV2Royalties(tokenId) returns (IRaribleV2.Part[] memory royalties) {
            // Supports rarible v2 interface. Compute amounts
            recipients = new address payable[](royalties.length);
            amounts = new uint256[](royalties.length);
            uint256 totalAmount;
            for (uint256 i = 0; i < royalties.length; i++) {
                recipients[i] = royalties[i].account;
                amounts[i] = (value * royalties[i].value) / 10_000;
                totalAmount += amounts[i];
            }
            if (totalAmount > value) revert InvalidAmount(totalAmount);
            return (recipients, amounts);
        } catch { }

        try IRaribleV1(tokenAddress).getFeeRecipients(tokenId) returns (address payable[] memory recipients_) {
            // Supports rarible v1 interface. Compute amounts
            recipients_ = IRaribleV1(tokenAddress).getFeeRecipients(tokenId);
            try IRaribleV1(tokenAddress).getFeeBps(tokenId) returns (uint256[] memory bps) {
                if (recipients_.length != bps.length) {
                    revert LengthMismatch(recipients_.length, bps.length);
                }
                return (recipients_, _computeAmounts(value, bps));
            } catch { }
        } catch { }

        try IZoraOverride(tokenAddress).convertBidShares(tokenAddress, tokenId) returns (
            address payable[] memory recipients_, uint256[] memory bps
        ) {
            // Support Zora override
            if (recipients_.length != bps.length) {
                revert LengthMismatch(recipients_.length, bps.length);
            }
            return (recipients_, _computeAmounts(value, bps));
        } catch { }

        try IArtBlocksOverride(tokenAddress).getRoyalties(tokenAddress, tokenId) returns (
            address payable[] memory recipients_, uint256[] memory bps
        ) {
            // Support Art Blocks override
            if (recipients_.length != bps.length) {
                revert LengthMismatch(recipients_.length, bps.length);
            }
            return (recipients_, _computeAmounts(value, bps));
        } catch { }

        try IKODAV2Override(tokenAddress).getKODAV2RoyaltyInfo(tokenAddress, tokenId, value) returns (
            address payable[] memory _recipients, uint256[] memory _amounts
        ) {
            // Support KODA V2 override
            if (_recipients.length != _amounts.length) {
                revert LengthMismatch(_recipients.length, _amounts.length);
            }
            return (_recipients, _amounts);
        } catch { }

        // No supported royalties configured
        return (recipients, amounts);
    }

    /**
     * Compute royalty amounts
     */
    function _computeAmounts(uint256 value, uint256[] memory bps) private pure returns (uint256[] memory amounts) {
        amounts = new uint256[](bps.length);
        uint256 totalAmount;
        for (uint256 i = 0; i < bps.length; i++) {
            amounts[i] = (value * bps[i]) / 10_000;
            totalAmount += amounts[i];
        }
        if (totalAmount > value) revert InvalidAmount(totalAmount);
        return amounts;
    }
}
