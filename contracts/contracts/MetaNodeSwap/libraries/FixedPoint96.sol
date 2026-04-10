// 【作用】定义 Q64.96 定点数的常量
// sqrtPriceX96 就是用这个格式存储的：实际值 = 存储值 / 2^96
// 为什么用定点数？因为 Solidity 没有浮点数，用整数模拟小数

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.4.0;

/// @title FixedPoint96
/// @notice A library for handling binary fixed point numbers, see https://en.wikipedia.org/wiki/Q_(number_format)
/// @dev Used in SqrtPriceMath.sol
library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}
