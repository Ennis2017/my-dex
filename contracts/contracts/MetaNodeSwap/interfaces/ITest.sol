// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

interface IMintCallback {
  function mintCallback(
    uint256 amount0Owed,
    uint256 amount1Owed,
    bytes calldata data
  ) external;
}

interface ISwapCallback {
  function swapCallback(
    int256 amount0Delta,
    int256 amount1Delta,
    bytes calldata data
  ) external;
}

interface IPool {
  function factory() external view returns (address);

  function token0() external view returns(address);

  function token1() external view returns(address);

  function fee() external view returns (uint24);

  function tickLower() external view returns(int24);

  function tickUpper() external view returns (int24);

  function sqrtPriceX96() external view returns (uint160);

  function tick() external view returns (int24);

  function liquidity() external view returns (uint128);

  function feeGrowthGlobal0X128() external view returns (uint256);

  function feeGrowthGlobal1X128() external view returns (uint256);

  function getPosition(
    address owner
  ) external view returns (
    uint128 _liquidity,
    uint256 feeGrowthInside0LastX128,
    uint256 feeGrowthInside1LastX128,
    uint128 tokensOwed0,
    uint128 tokensOwed1
  );
}
