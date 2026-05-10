// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/**
 * @title MockERC20
 * @author Alex Blom
 * @dev Mock ERC20 token for testing DEX functionality
 * Includes minting capability for easy testing
 */

contract MockERC20 is ERC20, Ownable {
    uint8 private _decimals;

    uint256 public constant FAUCET_AMOUNT = 1000;
    uint256 public constant FAUCET_COOLDOWN = 24 hours;
    mapping(address => uint256) public lastFaucetClaim;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        uint256 initialSupply
    )  ERC20(name, symbol) Ownable(msg.sender) {
        _decimals = decimals_;
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Returns the number of decimals used to get its user representation
     */

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

        /**
     * @dev Mint tokens to specified address (only owner)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */

         function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Burn tokens from caller's balance
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Public faucet — mints FAUCET_AMOUNT tokens to caller, once per FAUCET_COOLDOWN.
     */
    function faucet() external {
        require(
            block.timestamp >= lastFaucetClaim[msg.sender] + FAUCET_COOLDOWN,
            "MockERC20: faucet cooldown active"
        );
        lastFaucetClaim[msg.sender] = block.timestamp;
        _mint(msg.sender, FAUCET_AMOUNT * 10 ** _decimals);
    }
}