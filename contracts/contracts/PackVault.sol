// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IKanaRouter.sol";

/**
 * @title PackVault
 * @notice Manages pooled crypto investments organized into themed packs
 * @dev Handles deposits, withdrawals, rebalancing, and multi-token pack allocations
 */
contract PackVault is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // ============ Structs ============

    struct Pack {
        string packId;
        string name;
        uint256 totalValueLocked; // in USDC equivalent
        TokenAllocation[] allocations;
        uint256 lastRebalanceTimestamp;
        bool active;
    }

    struct TokenAllocation {
        address tokenAddress;
        uint16 weightBps; // basis points, 10000 = 100%
        uint256 currentBalance;
    }

    struct DepositParams {
        string packId;
        uint256 usdcAmount;
        address userSmartAccount;
        bytes32 referenceId;
    }

    struct WithdrawParams {
        string packId;
        uint256 sharesToBurn;
        address recipient;
        bool convertToStable;
    }

    // ============ State Variables ============

    // Pack registry
    mapping(string => Pack) public packs;
    string[] public packIds;

    // User shares per pack
    mapping(string => mapping(address => uint256)) public userShares;
    mapping(string => uint256) public totalShares;

    // External dependencies
    IPriceOracle public priceOracle;
    IKanaRouter public kanaRouter;
    address public paymasterService;
    IERC20 public immutable USDC;

    // Access control
    address public operator; // Backend service address
    
    // Rate limiting
    mapping(address => mapping(string => uint256)) public dailyDepositVolume;
    mapping(address => uint256) public lastDepositReset;
    uint256 public constant MAX_DAILY_DEPOSIT = 1_000_000 * 10**6; // $1M USDC

    // Configuration
    uint16 public constant MAX_SLIPPAGE_BPS = 200; // 2%
    uint16 public constant PRICE_DEVIATION_LIMIT_BPS = 150; // 1.5%
    uint256 public constant REBALANCE_COOLDOWN = 7 days;

    // ============ Events ============

    event PackCreated(
        string indexed packId,
        string name,
        uint256 timestamp
    );

    event PackDeposit(
        address indexed user,
        string indexed packId,
        uint256 usdcAmount,
        uint256 sharesMinted,
        bytes32 referenceId,
        uint256 timestamp
    );

    event PackWithdraw(
        address indexed user,
        string indexed packId,
        uint256 sharesBurned,
        uint256 usdcValue,
        uint256 timestamp
    );

    event PackRebalanced(
        string indexed packId,
        TokenAllocation[] newAllocations,
        uint256 timestamp
    );

    event EmergencyPause(string reason, uint256 timestamp);
    event EmergencyUnpause(uint256 timestamp);

    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);

    // ============ Modifiers ============

    modifier onlyOperator() {
        require(msg.sender == operator || msg.sender == owner(), "Not authorized");
        _;
    }

    modifier packExists(string memory packId) {
        require(packs[packId].active, "Pack does not exist");
        _;
    }

    modifier checkRateLimit(address user, string memory packId, uint256 amount) {
        _checkRateLimit(user, packId, amount);
        _;
    }

    // ============ Constructor ============

    constructor(
        address _priceOracle,
        address _kanaRouter,
        address _paymasterService,
        address _usdcToken
    ) Ownable(msg.sender) {
        require(_priceOracle != address(0), "Invalid oracle");
        require(_kanaRouter != address(0), "Invalid router");
        require(_usdcToken != address(0), "Invalid USDC");

        priceOracle = IPriceOracle(_priceOracle);
        kanaRouter = IKanaRouter(_kanaRouter);
        paymasterService = _paymasterService;
        USDC = IERC20(_usdcToken);
        operator = msg.sender;
    }

    // ============ Admin Functions ============

    /**
     * @notice Create a new investment pack
     * @param packId Unique identifier for the pack
     * @param name Display name
     * @param initialAllocations Token weights (must sum to 10000 bps)
     */
    function createPack(
        string memory packId,
        string memory name,
        TokenAllocation[] memory initialAllocations
    ) external onlyOwner {
        require(!packs[packId].active, "Pack already exists");
        require(initialAllocations.length > 0, "No allocations");
        
        uint16 totalWeight = 0;
        for (uint i = 0; i < initialAllocations.length; i++) {
            totalWeight += initialAllocations[i].weightBps;
        }
        require(totalWeight == 10000, "Weights must sum to 100%");

        Pack storage pack = packs[packId];
        pack.packId = packId;
        pack.name = name;
        pack.lastRebalanceTimestamp = block.timestamp;
        pack.active = true;

        for (uint i = 0; i < initialAllocations.length; i++) {
            pack.allocations.push(initialAllocations[i]);
        }

        packIds.push(packId);

        emit PackCreated(packId, name, block.timestamp);
    }

    /**
     * @notice Rebalance a pack to new token allocations
     * @param packId Pack to rebalance
     * @param newAllocations New token weights
     */
    function rebalance(
        string memory packId,
        TokenAllocation[] memory newAllocations
    ) external onlyOwner packExists(packId) {
        Pack storage pack = packs[packId];
        
        require(
            block.timestamp >= pack.lastRebalanceTimestamp + REBALANCE_COOLDOWN,
            "Rebalance cooldown not met"
        );

        uint16 totalWeight = 0;
        for (uint i = 0; i < newAllocations.length; i++) {
            totalWeight += newAllocations[i].weightBps;
        }
        require(totalWeight == 10000, "Weights must sum to 100%");

        // Clear existing allocations
        delete pack.allocations;

        // Set new allocations
        for (uint i = 0; i < newAllocations.length; i++) {
            pack.allocations.push(newAllocations[i]);
        }

        pack.lastRebalanceTimestamp = block.timestamp;

        emit PackRebalanced(packId, newAllocations, block.timestamp);
    }

    /**
     * @notice Emergency pause all operations
     */
    function pause(string memory reason) external onlyOwner {
        _pause();
        emit EmergencyPause(reason, block.timestamp);
    }

    /**
     * @notice Resume operations
     */
    function unpause() external onlyOwner {
        _unpause();
        emit EmergencyUnpause(block.timestamp);
    }

    /**
     * @notice Emergency withdraw tokens
     */
    function emergencyWithdrawToken(
        address token,
        uint256 amount,
        address recipient
    ) external onlyOwner {
        IERC20(token).safeTransfer(recipient, amount);
    }

    /**
     * @notice Update operator address
     */
    function setOperator(address newOperator) external onlyOwner {
        require(newOperator != address(0), "Invalid operator");
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    /**
     * @notice Update price oracle
     */
    function setPriceOracle(address newOracle) external onlyOwner {
        require(newOracle != address(0), "Invalid oracle");
        address oldOracle = address(priceOracle);
        priceOracle = IPriceOracle(newOracle);
        emit OracleUpdated(oldOracle, newOracle);
    }

    // ============ User Functions ============

    /**
     * @notice Deposit USDC and receive pack shares
     * @param params Deposit parameters
     * @return shares Number of shares minted
     */
    function deposit(DepositParams memory params)
        external
        nonReentrant
        whenNotPaused
        packExists(params.packId)
        checkRateLimit(params.userSmartAccount, params.packId, params.usdcAmount)
        returns (uint256 shares)
    {
        require(params.usdcAmount > 0, "Amount must be > 0");
        require(params.userSmartAccount != address(0), "Invalid user address");

        // Transfer USDC from user
        USDC.safeTransferFrom(msg.sender, address(this), params.usdcAmount);

        // Calculate shares to mint
        shares = _calculateShares(params.packId, params.usdcAmount);

        // Update state
        userShares[params.packId][params.userSmartAccount] += shares;
        totalShares[params.packId] += shares;
        packs[params.packId].totalValueLocked += params.usdcAmount;

        // Execute swaps to pack allocations (handled by Kana Router)
        _executeSwaps(params.packId, params.usdcAmount);

        emit PackDeposit(
            params.userSmartAccount,
            params.packId,
            params.usdcAmount,
            shares,
            params.referenceId,
            block.timestamp
        );
    }

    /**
     * @notice Withdraw by burning shares
     * @param params Withdrawal parameters
     * @return amounts Token amounts returned to user
     */
    function withdraw(WithdrawParams memory params)
        external
        nonReentrant
        whenNotPaused
        packExists(params.packId)
        returns (uint256[] memory amounts)
    {
        require(params.sharesToBurn > 0, "Shares must be > 0");
        require(
            userShares[params.packId][msg.sender] >= params.sharesToBurn,
            "Insufficient shares"
        );

        Pack storage pack = packs[params.packId];
        uint256 totalPackShares = totalShares[params.packId];

        // Calculate user's proportion
        uint256 userProportion = (params.sharesToBurn * 1e18) / totalPackShares;

        // Burn shares
        userShares[params.packId][msg.sender] -= params.sharesToBurn;
        totalShares[params.packId] -= params.sharesToBurn;

        // Transfer proportional tokens to user
        amounts = new uint256[](pack.allocations.length);
        uint256 totalValue = 0;

        for (uint i = 0; i < pack.allocations.length; i++) {
            TokenAllocation storage allocation = pack.allocations[i];
            uint256 tokenAmount = (allocation.currentBalance * userProportion) / 1e18;

            if (params.convertToStable) {
                // Swap to USDC via Kana Router (simplified)
                uint256 usdcAmount = _swapToUSDC(allocation.tokenAddress, tokenAmount);
                totalValue += usdcAmount;
            } else {
                // Transfer tokens directly
                IERC20(allocation.tokenAddress).safeTransfer(params.recipient, tokenAmount);
                amounts[i] = tokenAmount;
            }

            allocation.currentBalance -= tokenAmount;
        }

        if (params.convertToStable) {
            USDC.safeTransfer(params.recipient, totalValue);
        }

        pack.totalValueLocked -= totalValue;

        emit PackWithdraw(
            msg.sender,
            params.packId,
            params.sharesToBurn,
            totalValue,
            block.timestamp
        );
    }

    // ============ View Functions ============

    /**
     * @notice Get total value of a pack in USDC
     */
    function getPackValue(string memory packId)
        external
        view
        packExists(packId)
        returns (uint256 totalValue)
    {
        Pack storage pack = packs[packId];
        
        for (uint i = 0; i < pack.allocations.length; i++) {
            TokenAllocation storage allocation = pack.allocations[i];
            (uint256 tokenPrice, ) = priceOracle.getPrice(allocation.tokenAddress);
            totalValue += (allocation.currentBalance * tokenPrice) / 1e18;
        }
    }

    /**
     * @notice Get user's value in a pack
     */
    function getUserValue(string memory packId, address user)
        external
        view
        packExists(packId)
        returns (uint256 userValue)
    {
        uint256 shares = userShares[packId][user];
        if (shares == 0) return 0;

        uint256 totalPackShares = totalShares[packId];
        uint256 totalPackValue = this.getPackValue(packId);

        userValue = (totalPackValue * shares) / totalPackShares;
    }

    /**
     * @notice Get pack composition
     */
    function getPackComposition(string memory packId)
        external
        view
        packExists(packId)
        returns (TokenAllocation[] memory)
    {
        return packs[packId].allocations;
    }

    /**
     * @notice Get all pack IDs
     */
    function getAllPacks() external view returns (string[] memory) {
        return packIds;
    }

    // ============ Internal Functions ============

    /**
     * @notice Calculate shares to mint based on deposit
     */
    function _calculateShares(string memory packId, uint256 usdcAmount)
        internal
        view
        returns (uint256 shares)
    {
        uint256 totalPackShares = totalShares[packId];
        
        if (totalPackShares == 0) {
            // First deposit: 1:1 ratio
            shares = usdcAmount;
        } else {
            // Subsequent deposits: proportional to TVL
            uint256 totalValue = this.getPackValue(packId);
            shares = (usdcAmount * totalPackShares) / totalValue;
        }
    }

    /**
     * @notice Execute swaps via Kana Router
     * @dev Simplified implementation - actual integration needs Kana SDK
     */
    function _executeSwaps(string memory packId, uint256 usdcAmount) internal {
        Pack storage pack = packs[packId];

        for (uint i = 0; i < pack.allocations.length; i++) {
            TokenAllocation storage allocation = pack.allocations[i];
            uint256 amountForToken = (usdcAmount * allocation.weightBps) / 10000;

            // Approve Kana Router
            USDC.approve(address(kanaRouter), amountForToken);

            // Execute swap (simplified)
            IKanaRouter.SwapIntent memory intent = IKanaRouter.SwapIntent({
                fromToken: address(USDC),
                toToken: allocation.tokenAddress,
                amountIn: amountForToken,
                minAmountOut: _calculateMinOut(allocation.tokenAddress, amountForToken),
                deadline: block.timestamp + 600, // 10 min
                routeData: "" // Populated by Kana SDK off-chain
            });

            uint256 amountOut = kanaRouter.executeSwap(intent);
            allocation.currentBalance += amountOut;
        }
    }

    /**
     * @notice Calculate minimum output with slippage protection
     */
    function _calculateMinOut(address token, uint256 amountIn)
        internal
        view
        returns (uint256)
    {
        (uint256 expectedPrice, ) = priceOracle.getPrice(token);
        uint256 expectedOut = (amountIn * 1e18) / expectedPrice;
        
        // Apply slippage tolerance
        return (expectedOut * (10000 - MAX_SLIPPAGE_BPS)) / 10000;
    }

    /**
     * @notice Swap token to USDC (for withdrawals)
     */
    function _swapToUSDC(address token, uint256 amount)
        internal
        returns (uint256 usdcAmount)
    {
        IERC20(token).approve(address(kanaRouter), amount);

        IKanaRouter.SwapIntent memory intent = IKanaRouter.SwapIntent({
            fromToken: token,
            toToken: address(USDC),
            amountIn: amount,
            minAmountOut: 0, // Set proper slippage in production
            deadline: block.timestamp + 600,
            routeData: ""
        });

        usdcAmount = kanaRouter.executeSwap(intent);
    }

    /**
     * @notice Check and update rate limits
     */
    function _checkRateLimit(
        address user,
        string memory packId,
        uint256 amount
    ) internal {
        // Reset daily counter if 24h passed
        if (block.timestamp >= lastDepositReset[user] + 1 days) {
            dailyDepositVolume[user][packId] = 0;
            lastDepositReset[user] = block.timestamp;
        }

        dailyDepositVolume[user][packId] += amount;
        require(
            dailyDepositVolume[user][packId] <= MAX_DAILY_DEPOSIT,
            "Daily deposit limit exceeded"
        );
    }
}
