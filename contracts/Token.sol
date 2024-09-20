// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenContract is ERC20, Ownable {

    uint8 private immutable tokenDecimals; // variable to store the decimals value.

    // Constructor that initializes the ERC20 token with a name, symbol, and decimals provided by the user.
    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol) Ownable(msg.sender) {
        tokenDecimals = _decimals; // Set the decimals value during deployment.
    }

   // Override the decimals function to return the custom decimals value.
    function decimals() public view virtual override returns (uint8) {
        return tokenDecimals;
    }

  // Function to mint tokens, only callable by the deployer.
    function mint(uint256 value) public onlyOwner {
        _mint(msg.sender, value * (10 ** uint256(decimals())));
    }

}
