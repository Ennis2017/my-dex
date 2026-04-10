// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

// ============ 回调接口 ============

/// @notice 添加流动性的回调接口
/// 当 Pool.mint() 被调用时，Pool 会回调这个函数，要求调用方把代币转进来
/// 类比：你在淘宝下单后，淘宝回调支付接口要求你付款
interface IMintCallback {
    /// @param amount0Owed 需要转入的 token0 数量
    /// @param amount1Owed 需要转入的 token1 数量
    /// @param data 透传数据（调用方自定义，比如传递 payer 地址）
    function mintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;
}

/// @notice 交换代币的回调接口
/// 当 Pool.swap() 被调用时，Pool 会回调这个函数，要求调用方把输入代币转进来
interface ISwapCallback {
    /// @param amount0Delta token0 的变化量（正数=需要转入，负数=会转出给你）
    /// @param amount1Delta token1 的变化量（同上）
    /// @param data 透传数据
    function swapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}

// ============ Pool 主接口 ============

/// @notice Pool 合约的接口，定义了 DEX 流动性池的所有对外功能
interface IPool {
    // ---- 状态变量的 getter（Solidity 的 public 变量会自动生成 getter 函数） ----

    /// @notice 创建这个池子的工厂合约地址
    function factory() external view returns (address);

    /// @notice 交易对中地址较小的代币（token0 < token1，这是 Uniswap 的约定）
    function token0() external view returns (address);

    /// @notice 交易对中地址较大的代币
    function token1() external view returns (address);

    /// @notice 手续费率（单位：百万分之一，如 3000 = 0.3%）
    function fee() external view returns (uint24);

    /// @notice 价格区间下界的 tick 值
    function tickLower() external view returns (int24);

    /// @notice 价格区间上界的 tick 值
    function tickUpper() external view returns (int24);

    /// @notice 当前价格的平方根（Q64.96 定点数格式）
    /// 为什么存平方根？因为 AMM 数学公式里大量用到 sqrt(price)，直接存储避免反复计算
    function sqrtPriceX96() external view returns (uint160);

    /// @notice 当前价格对应的 tick 索引（price = 1.0001^tick）
    function tick() external view returns (int24);

    /// @notice 当前池子的总活跃流动性
    function liquidity() external view returns (uint128);

    /// @notice 每单位流动性累计的 token0 手续费（Q128.128 定点数）
    function feeGrowthGlobal0X128() external view returns (uint256);

    /// @notice 每单位流动性累计的 token1 手续费（Q128.128 定点数）
    function feeGrowthGlobal1X128() external view returns (uint256);

    /// @notice 查询某个地址的持仓信息
    function getPosition(
        address owner
    )
        external
        view
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    // ---- 核心操作函数 ----

    /// @notice 初始化池子价格，只能调用一次
    function initialize(uint160 sqrtPriceX96) external;

    /// @notice 添加流动性（铸造 LP 份额）
    /// @return amount0 实际需要的 token0 数量
    /// @return amount1 实际需要的 token1 数量
    function mint(
        address recipient,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice 移除流动性（销毁 LP 份额），不会立即转出代币，需要再调 collect
    function burn(
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice 提取代币（burn 退出的本金 + 累计的手续费）
    function collect(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    /// @notice 代币兑换
    /// @param recipient 接收兑换结果的地址
    /// @param zeroForOne 兑换方向：true = token0 换 token1，false = 反向
    /// @param amountSpecified 兑换数量（正数=精确输入，负数=精确输出）
    /// @param sqrtPriceLimitX96 价格限制（防止滑点过大）
    /// @param data 透传给回调函数的数据
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    // ---- 事件（类似前端的 EventEmitter，链上日志，前端可以监听） ----

    event Mint(
        address sender,
        address indexed owner,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    event Burn(
        address indexed owner,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    event Collect(
        address indexed owner,
        address recipient,
        uint128 amount0,
        uint128 amount1
    );

    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );
}
