// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract ERC1155Recipient {
    address public operator;
    address public from;
    uint256 public id;
    uint256 public amount;
    bytes public mintData;

    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _id,
        uint256 _amount,
        bytes calldata _data
    )
        public
        returns (bytes4)
    {
        operator = _operator;
        from = _from;
        id = _id;
        amount = _amount;
        mintData = _data;

        return 0xf23a6e61;
    }

    address public batchOperator;
    address public batchFrom;
    uint256[] internal _batchIds;
    uint256[] internal _batchAmounts;
    bytes public batchData;

    function batchIds() external view returns (uint256[] memory) {
        return _batchIds;
    }

    function batchAmounts() external view returns (uint256[] memory) {
        return _batchAmounts;
    }

    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    )
        external
        returns (bytes4)
    {
        batchOperator = _operator;
        batchFrom = _from;
        _batchIds = _ids;
        _batchAmounts = _amounts;
        batchData = _data;

        return 0xbc197c81;
    }
}

contract RevertingERC1155Recipient {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure returns (bytes4) {
        revert("0xf23a6e61");
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    )
        external
        pure
        returns (bytes4)
    {
        revert("0xf23a6e61");
    }
}

contract WrongReturnDataERC1155Recipient {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure returns (bytes4) {
        return 0xCAFEBEEF;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    )
        external
        pure
        returns (bytes4)
    {
        return 0xCAFEBEEF;
    }
}

contract NonERC1155Recipient { }
