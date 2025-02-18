// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../ERC721.sol";
import "../../common/Metadata.sol";
import "src/utils/Strings.sol";

/**
 * @dev ERC721 token with storage based token URI management.
 */
abstract contract ERC721Metadata_URI_autoIncrementID is ERC721, Metadata {
    using Strings for uint256;
    /// @dev address of the contract containing the code for the generative art (P5.js or similar)

    address private _deployedContract;

    /**
     * @notice Returns the URI for token type `tokenId`.
     * @dev Throws if `_exists(tokenId)` is not true.
     * @param _tokenId The token ID to query.
     * @return The URI of the token.
     */
    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        require(_exists(_tokenId));

        if (_deployedContract == address(0)) {
            return string(abi.encodePacked(_baseURI, _tokenId.toString()));
        } else {
            return string(
                abi.encodePacked(
                    _baseURI, // Ensure _baseURI ends with '/'
                    uint256(uint160(_deployedContract)).toHexString(20),
                    "/",
                    _tokenId.toString()
                )
            );
        }
    }

    /**
     * @notice Sets the base URI and the deployed contract address.
     * @dev Child contract MAY require access control to the external function implementation.
     * @param baseURI_ The new base URI.
     * @param deployedContract_ The address of the deployed contract, set to address(0) if not applicable to baseURI,
     * see tokenURI().
     */
    function _setBaseURI(string memory baseURI_, address deployedContract_) internal {
        _baseURI = baseURI_;

        _deployedContract = deployedContract_;
    }
}
