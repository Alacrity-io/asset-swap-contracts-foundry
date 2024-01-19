// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {CarNFT} from "../src/CarNFT.sol";

contract CarNftTest is Test {
    CarNFT public nft;
    //addresses
    address buyer = address(0x7);
    address seller = address(0x1);
    uint256 price = 0.2 * 1e18;

    function setUp() public {
        nft = new CarNFT(price, buyer, seller);
    }

    function testConstructor() public {
        assertEq(nft.getBuyer(), buyer);
        assertEq(nft.getSeller(), seller);
        assertEq(nft.getPrice(), price);
        emit log_named_uint("the contracts' balance is ", price);
        emit log_named_uint("the token id is ", nft.getNftID());
    }

    function testMint() public {
        vm.startPrank(seller);
        nft.mint(buyer, "token transferred", seller);
        assertEq(buyer, nft.ownerOfToken(0));
        assertEq(nft.getNftID(), 1);
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.deal(address(nft), 3 ether);
        uint256 balance = address(nft).balance;
        assertEq(balance, 3 * 1e18);
        emit log_named_uint("balance in sc is ", balance);
        emit log_named_uint("balance in seller's account is ", address(seller).balance);
        vm.startPrank(seller);
        nft.withdraw(seller);
        balance = address(nft).balance;
        assertEq(balance, 0);
        assertEq(uint256(address(seller).balance), uint256(3 * 1e18));
        vm.stopPrank();
    }
}
