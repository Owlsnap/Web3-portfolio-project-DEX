// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Pair
 * @author Alex Blom
 * @dev AMM liquidity pool for two ERC20 tokens
 * Implements constant product formula (x * y = k)
 * Based on Uniswap V2 Pair contract
 */
contract Pair is ERC20 {
    address public factory; // Factory that created this pair

    
    // The two tokens in this pair
    address public token0;
    address public token1;
    
    // Current reserves (cached for gas efficiency)
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    // reserve0 * reserve1 after the most recent liquidity event, used for the protocol fee
    uint256 public kLast;

    // Minimum liquidity locked forever
    uint256 public constant MINIMUM_LIQUIDITY = 10**3; 
    
    // Dead address for burning minimum liquidity (instead of address(0))
    address private constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // Simple reentrancy guard
    uint256 private unlocked = 1;
    
    modifier lock() {
        require(unlocked == 1, "Pair: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }
    
    // Events
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() ERC20("DEX-LP", "DLP") {
        factory = msg.sender;
    }

    /**
     * @dev Initialize the pair with two tokens (called by Factory)
     * @param _token0 First token address (smaller address)
     * @param _token1 Second token address (larger address)
     */
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "Pair: FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
    }

    /**
     * @dev Get current reserves and last block timestamp
     * @return _reserve0 Current reserve of token0
     * @return _reserve1 Current reserve of token1
     * @return _blockTimestampLast Timestamp of last update
     */
    function getReserves() 
        public 
        view 
        returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) 
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * @dev Update reserves and timestamp
     * @param balance0 Current balance of token0 in contract
     * @param balance1 Current balance of token1 in contract
     */
    function _update(uint256 balance0, uint256 balance1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "Pair: OVERFLOW");
        
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        
        if (timeElapsed > 0 && reserve0 != 0 && reserve1 != 0) {
        // Update price accumulators for oracle functionality
        price0CumulativeLast += uint256((reserve1 << 112) / reserve0) * timeElapsed;
        price1CumulativeLast += uint256((reserve0 << 112) / reserve1) * timeElapsed;
        }
        
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        
        emit Sync(reserve0, reserve1);
    }

    /**
     * @dev Mint the protocol's share of fee growth (1/6 of LP fees) to the factory's feeTo
     * Same mechanism as Uniswap V2: fees are measured as growth in sqrt(k) since the last
     * liquidity event and paid out as newly minted LP tokens
     * @return feeOn Whether a protocol fee recipient is set
     */
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IFactoryFees(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast; // Gas optimization
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = _sqrt(uint256(_reserve0) * _reserve1);
                uint256 rootKLast = _sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply() * (rootK - rootKLast);
                    uint256 denominator = rootK * 5 + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    /**
     * @dev Mint LP tokens when liquidity is added
     * @param to Address to mint LP tokens to
     * @return liquidity Amount of LP tokens minted
     */
    function mint(address to) external lock returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // Get cached reserves
        uint256 balance0 = IERC20(token0).balanceOf(address(this)); // Check actual token0 balance
        uint256 balance1 = IERC20(token1).balanceOf(address(this)); // Check actual token1 balance
        uint256 amount0 = balance0 - _reserve0; // Calculate token0 deposited since last update
        uint256 amount1 = balance1 - _reserve1; // Calculate token1 deposited since last update

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply(); // Get current LP token supply (after protocol fee mint)
        if (_totalSupply == 0) {
            // First liquidity provider - use geometric mean
            liquidity = _sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(DEAD_ADDRESS, MINIMUM_LIQUIDITY); // Lock minimum liquidity forever (prevents attacks)
        } else {
            // Subsequent liquidity providers - proportional to existing ratio
            liquidity = _min(
                (amount0 * _totalSupply) / _reserve0, // LP based on token0 ratio
                (amount1 * _totalSupply) / _reserve1  // LP based on token1 ratio
            );
        }
        
        require(liquidity > 0, "Pair: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity); // Mint LP tokens to specified address

        _update(balance0, balance1);
        if (feeOn) kLast = uint256(reserve0) * reserve1;
        emit Mint(msg.sender, amount0, amount1);
    }

    /**
     * @dev Helper function to calculate square root
     */
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /**
     * @dev Helper function to find minimum of two numbers
     */
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Burn LP tokens and withdraw liquidity
     * @param to Address to send withdrawn tokens to
     * @return amount0 Amount of token0 withdrawn
     * @return amount1 Amount of token1 withdrawn
     */
    function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0; // Gas optimization - load from storage once
        address _token1 = token1; // Gas optimization - load from storage once
        uint256 balance0 = IERC20(_token0).balanceOf(address(this)); // Current token0 balance
        uint256 balance1 = IERC20(_token1).balanceOf(address(this)); // Current token1 balance
        uint256 liquidity = balanceOf(address(this)); // LP tokens to burn (sent to this contract)

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply(); // Get total LP supply (after protocol fee mint)
        amount0 = (liquidity * balance0) / _totalSupply; // Calculate proportional token0 share
        amount1 = (liquidity * balance1) / _totalSupply; // Calculate proportional token1 share
        
        require(amount0 > 0 && amount1 > 0, "Pair: INSUFFICIENT_LIQUIDITY_BURNED");
        
        _burn(address(this), liquidity); // Destroy the LP tokens
        IERC20(_token0).transfer(to, amount0); // Send token0 to recipient
        IERC20(_token1).transfer(to, amount1); // Send token1 to recipient
        
        // Update balances after transfers and sync reserves
        balance0 = IERC20(_token0).balanceOf(address(this)); // New balance after transfer
        balance1 = IERC20(_token1).balanceOf(address(this)); // New balance after transfer

        _update(balance0, balance1); // Update reserves with new balances
        if (feeOn) kLast = uint256(reserve0) * reserve1;
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /**
     * @dev Swap tokens using constant product formula (x * y = k)
     * @param amount0Out Amount of token0 to send out
     * @param amount1Out Amount of token1 to send out  
     * @param to Address to send tokens to
     * @param data Callback data (for flash loans - can be empty)
     */
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) 
        external 
        lock 
    {
        require(amount0Out > 0 || amount1Out > 0, "Pair: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "Pair: INSUFFICIENT_LIQUIDITY");

        uint256 balance0;
        uint256 balance1;
        {
            // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, "Pair: INVALID_TO");
            
            // Send tokens to user FIRST (optimistic execution - trust but verify)
            if (amount0Out > 0) IERC20(_token0).transfer(to, amount0Out); // Send token0 if requested
            if (amount1Out > 0) IERC20(_token1).transfer(to, amount1Out); // Send token1 if requested
            
            // Callback for flash loans (allows complex operations with borrowed tokens)
            if (data.length > 0) ICallee(to).call(msg.sender, amount0Out, amount1Out, data);
            
            // Check balances AFTER sending tokens (and after potential callback)
            balance0 = IERC20(_token0).balanceOf(address(this)); // New balance after operations
            balance1 = IERC20(_token1).balanceOf(address(this)); // New balance after operations
        }
        
        // Calculate how much was sent IN (input tokens from user)
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        
        require(amount0In > 0 || amount1In > 0, "Pair: INSUFFICIENT_INPUT_AMOUNT");
        
        {
            // Scope to avoid "stack too deep" compilation error
            // Governance-controlled fee in basis points: flash swaps (with callback data) pay
            // the flash loan fee, regular swaps pay the trading fee. Router quotes use the same values.
            uint256 fee = data.length > 0
                ? IFactoryFees(factory).flashLoanFee()
                : IFactoryFees(factory).tradingFee();
            uint256 balance0Adjusted = (balance0 * 10000) - (amount0In * fee); // Fee-adjusted balance0
            uint256 balance1Adjusted = (balance1 * 10000) - (amount1In * fee); // Fee-adjusted balance1

            // Verify constant product formula: k_after >= k_before (accounting for fees)
            require(
                balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * _reserve1 * 10000**2,
                "Pair: K" // "K" constant product invariant violated
            );
        }

        _update(balance0, balance1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /**
     * @dev Force balances to match reserves (emergency function)
     */
    function skim(address to) external lock {
        address _token0 = token0; // Gas optimization
        address _token1 = token1; // Gas optimization
        IERC20(_token0).transfer(to, IERC20(_token0).balanceOf(address(this)) - reserve0); // Send excess token0
        IERC20(_token1).transfer(to, IERC20(_token1).balanceOf(address(this)) - reserve1); // Send excess token1
    }

    /**
     * @dev Force reserves to match balances (emergency function)  
     */
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this))); // Update reserves to actual balances
    }

}         /** END OF CONTRACT */

    // Fee settings read from the Factory (an interface avoids a circular import)
    interface IFactoryFees {
        function feeTo() external view returns (address);
        function tradingFee() external view returns (uint256);
        function flashLoanFee() external view returns (uint256);
    }

    // Interface for callback (flash loan functionality)
    interface ICallee {
        function call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
    }
