// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the checks-effects-interactions pattern
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern
     * @dev Sends `_amount` wei to `_receiver`, forwarding all available gas and reverting on errors.
     * This function is a replacement for Solidity's `transfer` which has a limitation due to EIP1884.
     * @param _receiver The address of the recipient.
     * @param _amount The amount to be sent.
     */
    function sendValue(address _receiver, uint256 _amount) internal {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = payable(_receiver).call{ value: _amount }("");
        require(success);
    }

    /**
     * @dev Transfers ERC-721 tokens to the buyer via `transferFrom` rather than `safeTransferFrom`.
     * The caller is responsible to confirm that the recipient if a contract is capable of receiving and handling ERC721
     * and ERC1155 tokens.
     * @dev Send token to receiver, either ERC721 or ERC20 as they both have the same function signature for
     * `transferFrom`
     * bytes4(keccak256('transferFrom(address,address,uint256)')) == 0x23b872dd
     */
    function transferFrom(address _token, address _from, address _to, uint256 _tokenIdOrERC20Value) internal {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = _token.call(abi.encodeWithSelector(0x23b872dd, _from, _to, _tokenIdOrERC20Value));
        require(success);
    }
}
