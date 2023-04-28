// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/Treasury.sol";
import "../src/IUniswap.sol";
import "../src/Token.sol";


contract TreasuryTest is Test {
    Token USDT;
    Token DAI;
    Treasure treasury;

    function setUp() public {
        USDT = new Token("USD Tether", "USDT");
        DAI = new Token("DAI Stable Coin","DAI");
        treasury = new Treasure("LP Token", "LPT");
    }
    
    function testName() public {
        assertEq(t.name(), "Token");
    }
}
