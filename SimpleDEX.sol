// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import OpenZeppelin SafeERC20 for safe token interactions
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title SimpleDEX
 * @notice A basic Automated Market Maker (AMM) DEX using the x * y = k model.
 */
contract SimpleDEX is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Token contracts
    IERC20 public tokenA;
    IERC20 public tokenB;

    // Reserves in the pool
    uint256 public reserveA;
    uint256 public reserveB;

    // Contract owner (initial liquidity provider)
    address public owner;

    // ====================
    // Events
    // ====================
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB);
    event Swapped(address indexed user, address fromToken, uint256 amountIn, uint256 amountOut);

    // ====================
    // Modifiers
    // ====================
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    // ====================
    // Constructor
    // ====================
    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        owner = msg.sender;
    }

    // ====================
    // Liquidity Functions
    // ====================

    /**
     * @notice Adds liquidity to the pool (only callable by the owner).
     * @param amountA Amount of tokenA to add.
     * @param amountB Amount of tokenB to add.
     */
    function addLiquidity(uint256 amountA, uint256 amountB) external onlyOwner nonReentrant {
        require(amountA > 0 && amountB > 0, "Amounts must be greater than zero");

        tokenA.safeTransferFrom(msg.sender, address(this), amountA);
        tokenB.safeTransferFrom(msg.sender, address(this), amountB);

        reserveA += amountA;
        reserveB += amountB;

        emit LiquidityAdded(msg.sender, amountA, amountB);
    }

    /**
     * @notice Removes liquidity from the pool (only callable by the owner).
     * @param amountA Amount of tokenA to remove.
     * @param amountB Amount of tokenB to remove.
     */
    function removeLiquidity(uint256 amountA, uint256 amountB) external onlyOwner nonReentrant {
        require(reserveA >= amountA && reserveB >= amountB, "Insufficient reserves");

        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.safeTransfer(msg.sender, amountA);
        tokenB.safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB);
    }

    // ====================
    // Swap Functions
    // ====================

    /**
     * @notice Swaps tokenA for tokenB using AMM logic with slippage control.
     * @param amountAIn Input amount of tokenA.
     * @param minBOut Minimum acceptable amount of tokenB (for slippage protection).
     * @return amountBOut Output amount of tokenB.
     */
    function swapAforB(uint256 amountAIn, uint256 minBOut) external nonReentrant returns (uint256 amountBOut) {
        require(amountAIn > 0, "Input amount must be greater than zero");
        require(reserveA > 0 && reserveB > 0, "Insufficient liquidity");

        tokenA.safeTransferFrom(msg.sender, address(this), amountAIn);

        uint256 amountInWithFee = amountAIn * 997;
        uint256 numerator = amountInWithFee * reserveB;
        uint256 denominator = (reserveA * 1000) + amountInWithFee;
        amountBOut = numerator / denominator;

        require(amountBOut >= minBOut, "Slippage too high");
        require(reserveB - amountBOut >= 1, "Cannot drain reserves");

        tokenB.safeTransfer(msg.sender, amountBOut);

        reserveA += amountAIn;
        reserveB -= amountBOut;

        emit Swapped(msg.sender, address(tokenA), amountAIn, amountBOut);
    }

    /**
     * @notice Swaps tokenB for tokenA using AMM logic with slippage control.
     * @param amountBIn Input amount of tokenB.
     * @param minAOut Minimum acceptable amount of tokenA (for slippage protection).
     * @return amountAOut Output amount of tokenA.
     */
    function swapBforA(uint256 amountBIn, uint256 minAOut) external nonReentrant returns (uint256 amountAOut) {
        require(amountBIn > 0, "Input amount must be greater than zero");
        require(reserveA > 0 && reserveB > 0, "Insufficient liquidity");

        tokenB.safeTransferFrom(msg.sender, address(this), amountBIn);

        uint256 amountInWithFee = amountBIn * 997;
        uint256 numerator = amountInWithFee * reserveA;
        uint256 denominator = (reserveB * 1000) + amountInWithFee;
        amountAOut = numerator / denominator;

        require(amountAOut >= minAOut, "Slippage too high");
        require(reserveA - amountAOut >= 1, "Cannot drain reserves");

        tokenA.safeTransfer(msg.sender, amountAOut);

        reserveB += amountBIn;
        reserveA -= amountAOut;

        emit Swapped(msg.sender, address(tokenB), amountBIn, amountAOut);
    }

    // ====================
    // Price View Function
    // ====================

    /**
     * @notice Returns the current price of a token in terms of the other token.
     * @param _token Address of the token to query.
     * @return price Price scaled to 1e18.
     */
    function getPrice(address _token) external view returns (uint256 price) {
        require(_token == address(tokenA) || _token == address(tokenB), "Invalid token");

        if (_token == address(tokenA)) {
            return (reserveB * 1e18) / reserveA;
        } else {
            return (reserveA * 1e18) / reserveB;
        }
    }
}
