// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

/// @notice 工厂合约接口，负责创建和管理 Pool
/// 类比：工厂模式 —— 一个工厂可以生产多个 Pool 实例
interface IFactory {
    /// @notice 创建 Pool 时的临时参数结构体
    /// 为什么不直接通过构造函数传参？因为要用 CREATE2 提前计算 Pool 地址，
    /// 构造函数参数会影响地址计算，所以改用临时存储 + Pool 构造时自己来读取
    struct Parameters {
        address factory;   // 工厂合约自身地址
        address tokenA;    // 代币 A 地址
        address tokenB;    // 代币 B 地址
        int24 tickLower;   // 价格区间下界
        int24 tickUpper;   // 价格区间上界
        uint24 fee;        // 手续费率
    }

    /// @notice Pool 构造函数中调用这个来获取初始化参数
    function parameters()
        external
        view
        returns (
            address factory,
            address tokenA,
            address tokenB,
            int24 tickLower,
            int24 tickUpper,
            uint24 fee
        );

    /// @notice 池子创建事件
    event PoolCreated(
        address token0,
        address token1,
        uint32 index,      // 同一交易对可以有多个池子（不同费率），index 是序号
        int24 tickLower,
        int24 tickUpper,
        uint24 fee,
        address pool       // 新创建的池子合约地址
    );

    /// @notice 查询某个交易对的第 index 个池子地址
    function getPool(
        address tokenA,
        address tokenB,
        uint32 index
    ) external view returns (address pool);

    /// @notice 创建新的流动性池
    function createPool(
        address tokenA,
        address tokenB,
        int24 tickLower,
        int24 tickUpper,
        uint24 fee
    ) external returns (address pool);
}
