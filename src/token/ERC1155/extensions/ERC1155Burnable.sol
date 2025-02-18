// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../ERC1155.sol";

/**
 *
 * @title ERC1155Burnable                                    *
 *                                                           *
 * @notice  ERC-1155 burnable extension                      *
 *                                                           *
 * @custom:security-contact tech@ninfa.io                    *
 *
 */
contract ERC1155Burnable is ERC1155 {
    /**
     * @notice Burns a specific token.
     * @dev TokenURI is not deleted when a token is burned, for efficiency reasons,
     * as that would require an additional if statement in the _burn function;
     * the savings from deleting tokenURI do not offset the gas cost of the additional if statement.
     * This does not pose any security risks.
     * @param _from The owner of the token.
     * @param _id The token ID to burn.
     * @param _value The amount of tokens to burn.
     */
    function burn(address _from, uint256 _id, uint256 _value) external {
        // implicitly checks `require(_from != address(0))`
        require(_from == msg.sender || isApprovedForAll[_from][msg.sender]);

        _burn(_from, _id, _value);
    }
}
