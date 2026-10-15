// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TokenFaucet
 * @author Alex Blom
 * @dev Hands out a fixed amount of a pre-funded token, once per address per cooldown.
 * Used on testnet so visitors can get PROTO (fixed supply, no mint) to vote with.
 */
contract TokenFaucet {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    uint256 public immutable dripAmount;
    uint256 public immutable cooldown;

    mapping(address => uint256) public lastClaim;

    event Claimed(address indexed account, uint256 amount);

    constructor(IERC20 _token, uint256 _dripAmount, uint256 _cooldown) {
        token = _token;
        dripAmount = _dripAmount;
        cooldown = _cooldown;
    }

    /**
     * @dev Send dripAmount tokens to the caller (anyone can fund the faucet by transferring tokens to it)
     */
    function claim() external {
        require(
            lastClaim[msg.sender] == 0 || block.timestamp >= lastClaim[msg.sender] + cooldown,
            "TokenFaucet: cooldown active"
        );
        require(token.balanceOf(address(this)) >= dripAmount, "TokenFaucet: empty");
        lastClaim[msg.sender] = block.timestamp;
        token.safeTransfer(msg.sender, dripAmount);
        emit Claimed(msg.sender, dripAmount);
    }

    /**
     * @dev Timestamp when `account` can claim again (0 if it can claim now)
     */
    function nextClaimAt(address account) external view returns (uint256) {
        uint256 last = lastClaim[account];
        if (last == 0 || block.timestamp >= last + cooldown) return 0;
        return last + cooldown;
    }
}
