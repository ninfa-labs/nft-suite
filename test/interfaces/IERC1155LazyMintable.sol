// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import { EncodeType } from "src/token/common/EncodeType.sol";

interface IERC1155LazyMintable {
    function lazyMint(
        EncodeType.TokenVoucher calldata _voucher,
        bytes calldata _signature,
        bytes calldata _data,
        address _to,
        uint256 _value,
        uint256 _tokenId
    )
        external
        payable;

    function lazyBuy(
        EncodeType.TokenVoucher memory _voucher,
        bytes calldata _signature,
        bytes calldata _data,
        address _to,
        uint256 _value
    )
        external
        payable;
}
