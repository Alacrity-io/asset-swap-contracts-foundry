// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {CarNFT} from "../src/CarNFT.sol";

contract CarNftTest is Test {
    CarNFT public nft;
    //addresses
    address buyer = address(0x0);
    address seller = address(0x1);
    uint256 price = 0.2 * 1e18;

    function setUp() public {
        nft = new CarNFT(price, buyer, seller, seller);
    }

    function testConstructor() public {
        assertEq(nft.getBuyer(), buyer);
        assertEq(nft.getSeller(), seller);
        assertEq(nft.getPrice(), price);
        emit log_named_uint("the contracts' balance is ", price);
        emit log_named_uint("the token id is ", nft.getNftID());
    }
}
