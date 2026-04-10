//SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libraries/SqrtPriceMath.sol";
import "./libraries/TickMath.sol";
import "./libraries/LiquidityMath.sol";
import "./libraries/LowGasSafeMath.sol";
import "./libraries/SafeCast.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/SwapMath.sol";
import "./libraries/FixedPoint128.sol";

import "./interfaces/IPool.sol";
import "./interfaces/IFactory.sol";

/// @notice 单一流动性池：一个代币对在固定价格区间[tickLower, tickUpper]内的流动性
contract Pool is IPool {
  // 给uint256 和 int256 类型挂载库函数，之后可以用x.add(y)的语法
  using SafeCast for uint256;
  using LowGasSafeMath for int256;
  using LowGasSafeMath for uint256;

  address public immutable override factory;
  address public immutable override token0;
  address public immutable override token1;
  uint24 public immutable override fee;
  int24 public immutable override tickLower;
  int24 public immutable override tickUpper;

  uint160 public override sqrtPriceX96;
  int24 public override tick;
  uint128 public override liquidity;

  // 手续费累计值（每单位流动性累计了多少手续费）
  uint256 public override feeGrowthGlobal0X128;
  uint256 public override feeGrowthGlobal1X128;

  struct Position {
    uint128 liquidity;
    uint128 tokensOwed0;
    uint128 tokensOwed1;
    uint256 feeGrowthInside0LastX128;
    uint256 feeGrowthInside1LastX128;
  }

  mapping(address => Position) public positions;

  function getPosition(
    address owner
  )
    external
    view
    override
    returns (
      uint128 _liquidity,
      uint256 feeGrowthInside0LastX128,
      uint256 feeGrowthInside1LastX128,
      uint128 tokensOwed0,
      uint128 tokensOwed1
    )
  {
    return (
      positions[owner].liquidity,
      positions[owner].feeGrowthInside0LastX128,
      positions[owner].feeGrowthInside1LastX128,
      positions[owner].tokensOwed0,
      positions[owner].tokensOwed1
    );
  }

  constructor() {
    // pool 不是直接部署的，而是由Factory 通过 new Pool{salt: salt}() 创建的
    // 参数不通过构造函数传入，而是从Factory 的 parameters() 函数读取
    // 原因： CREATE2 用 bytecode 算地址，如果构造函数带参数，bytecode会变化，地址就不稳定了
    (factory, token0, token1, tickLower, tickUpper, fee) = IFactory(
      msg.sender
    ).parameters();
  }

  function initialize(
    uint160 sqrtPriceX96_
  )
    external
    override
  {
    require(sqrtPriceX96 == 0, "initialize");
    tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96_);
    require(
      tick >= tickLower && tick <= tickUpper,
      'sqrtPriceX96 should be within the range of [tickLower, tickUpper]'
    );
    sqrtPriceX96 = sqrtPriceX96_;
  }

  struct ModifyPositionParams {
    address owner; // 持仓所有者
    int128 liquidityDelta; // 流动性变化量 正=添加，负=移除
  }

  /// @notice 修改持仓的核心内部函数
  function _modifyPosition(
    ModifyPositionParams memory params
  )
    private
    returns (
      int256 amount0,
      int256 amount1
    )
  {
    // 根据流动性变化量和价格区间，算出需要多少 token0 和 token1
    // 添加流动性时返回正数
    amount0 = SqrtPriceMath.getAmount0Delta(
      sqrtPriceX96,
      TickMath.getSqrtPriceAtTick(tickUpper),
      params.liquidityDelta
    );

    amount1 = SqrtPriceMath.getAmount1Delta(
      TickMath.getSqrtPriceAtTick(tickLower),
      sqrtPriceX96,
      params.liquidityDelta
    );

    // 获取这个地址的持仓
    Position storage position = positions[params.owner];
    uint128 tokensOwed0 = uint128(
      FullMath.mulDiv(
        feeGrowthGlobal0X128 - position.feeGrowthInside0LastX128,
        position.liquidity,
        FixedPoint128.Q128
      )
    );
    uint128 tokensOwed1 = uint128(
      FullMath.mulDiv(
        feeGrowthGlobal1X128 - position.feeGrowthInside1LastX128,
        position.liquidity,
        FixedPoint128.Q128
      )
    );

    // 更新基准值到当前 相当于：以结算到最新
    position.feeGrowthInside0LastX128 = feeGrowthGlobal0X128;
    position.feeGrowthInside1LastX128 = feeGrowthGlobal1X128;

    // 累加到可提取额度
    if (tokensOwed0 > 0 || tokensOwed1 > 0) {
      position.tokensOwed0 += tokensOwed0;
      position.tokensOwed1 += tokensOwed1;
    }

    // 更新全局流动性和持仓流动性
    liquidity = LiquidityMath.addDelta(liquidity, params.liquidityDelta);
    position.liquidity = LiquidityMath.addDelta(position.liquidity, params.liquidityDelta);
  }

  /// @dev 查询当前池子持有的token0余额
  function balance0()
    private
    view
    returns (
      uint256
    )
  {
    (bool success, bytes memory data) = token0.staticcall(
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
    );
    require(success && data.length >= 32);
    return abi.decode(data, (uint256));
  }

  /// @dev 查询池子当前持有的 token1 余额
  function balance1() private view returns (uint256) {
    (bool success, bytes memory data) = token1.staticcall(
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
    );
    require(success && data.length >= 32);
    return abi.decode(data, (uint256));
  }

  // 添加流动性
  /// @notice 向池子添加流动性
  function mint(
    address recipient,
    uint128 amount,
    bytes calldata data
  ) external
    override
    returns (
      uint256 amount0,
      uint256 amount1
    )
  {
    require(amount > 0, "Mint amount must be greater than 0");
    // 计算需要多少 token0 和 token1
    (int256 amount0Int, int256 amount1Int) = _modifyPosition(
        ModifyPositionParams({
            owner: recipient,
            liquidityDelta: int128(amount)  // 正数 = 添加
        })
    );
    amount0 = uint256(amount0Int);
    amount1 = uint256(amount1Int);

    // 回调模式：先记录余额 → 通知调用方转钱 → 验证余额增加了
    uint256 balance0Before;
    uint256 balance1Before;
    if (amount0 > 0) balance0Before = balance0();
    if (amount1 > 0) balance1Before = balance1();

    // 回调 PositionManager 的 mintCallback，让它把代币转进来
    IMintCallback(msg.sender).mintCallback(amount0, amount1, data);

    // 验证代币确实到账了
    if (amount0 > 0)
        require(balance0Before.add(amount0) <= balance0(), "M0");
    if (amount1 > 0)
        require(balance1Before.add(amount1) <= balance1(), "M1");

    emit Mint(msg.sender, recipient, amount, amount0, amount1);
  }

  // 移除流动性
  /// @notice 移除流动性，不会立即转出币
  function burn(
    uint128 amount
  ) external
    override
    returns (
      uint256 amount0,
      uint256 amount1
    )
  {
    require(amount > 0, 'amount need greater than 0');
    require(
      amount < positions[msg.sender].liquidity,
      'burn amount exceeds liquidity'
    );
    (int256 amount0Int, int256 amount1Int) = _modifyPosition(
      ModifyPositionParams({
        owner: msg.sender,
        liquidityDelta: -int128(amount)
      })
    );

    amount0 = uint256(-amount0Int);
    amount1 = uint256(-amount1Int);

    // 把退还的代币记账到 tokensOwed
    if(amount0 > 0 || amount1 > 0) {
      positions[msg.sender].tokensOwed0 += uint128(amount0);
      positions[msg.sender].tokensOwed1 += uint128(amount1);
    }

    emit Burn(msg.sender, amount, amount0, amount1);
  }
  // ============ collect：提取代币 ============
  /// @notice 提取代币（burn 退出的本金 + 累计的手续费）
  function collect(
    address recipient,
    uint128 amount0Requested,
    uint128 amount1Requested
  ) external
    override
    returns (
      uint128 amount0,
      uint128 amount1
    )
  {
    Position storage position = positions[msg.sender];

    // 实际提取量 = min(请求量, 可提取量)
    amount0 = amount0Requested > position.tokensOwed0
      ? position.tokensOwed0
      : amount0Requested;
    amount1 = amount1Requested > position.tokensOwed1
      ? position.tokensOwed1
      : amount1Requested;

    // 扣减记账 + 转代币
    if (amount0 > 0) {
      position.tokensOwed0 -= amount0;
      TransferHelper.safeTransfer(token0, recipient, amount0);
    }
    if (amount1 > 0) {
      position.tokensOwed1 -= amount1;
      TransferHelper.safeTransfer(token1, recipient, amount1);
    }

    emit Collect(msg.sender, recipient, amount0, amount1);
  }


  // swap
  struct SwapState {
    int256 amountSpecifiedRemaining; // 指定的剩下的余额（还剩多少没成交)
    int256 amountCalculated;        // 已经算出来的另一边数量
    uint160 sqrtPriceX96;           // 当前计算到的价格
    uint256 feeGrowthGlobalX128;     // 手续费累计值
    uint256 amountIn;
    uint256 amountOut;
    uint256 feeAmount;
  }

  /// @notice 执行代币兑换
  function swap(
    address recipient,
    bool zeroForOne,
    int256 amountSpecified,
    uint160 sqrtPriceLimitX96,
    bytes calldata data
  ) external
    override
    returns (
      int256 amount0,
      int256 amount1
    )
  {
    require(amountSpecified != 0, 'as');

    // 校验价格限制合法性
    require(
      zeroForOne
        ? sqrtPriceLimitX96 < sqrtPriceX96 && sqrtPriceLimitX96 > TickMath.MIN_SQRT_PRICE
        : sqrtPriceLimitX96 > sqrtPriceX96 && sqrtPriceLimitX96 > TickMath.MAX_SQRT_PRICE
    );

    bool exactInput = amountSpecified > 0;

    // 初始化临时状态
    SwapState memory state = SwapState({
      amountSpecifiedRemaining: amountSpecified,
      amountCalculated: 0,
      sqrtPriceX96: sqrtPriceX96,
      feeGrowthGlobalX128: zeroForOne
        ? feeGrowthGlobal0X128
        : feeGrowthGlobal1X128,
      amountIn: 0,
      amountOut: 0,
      feeAmount: 0
    });

    // 计算池子自身的价格边界
    uint160 sqrtPriceX96Lower = TickMath.getSqrtPriceAtTick(tickLower);
    uint160 sqrtPriceX96Upper = TickMath.getSqrtPriceAtTick(tickUpper);
    uint160 sqrtPriceX96PoolLimit = zeroForOne
      ? sqrtPriceX96Lower
      : sqrtPriceX96Upper;

    // 核心计算：取用户限制和池子边界中更严格的那个作为目标价
    (
      state.sqrtPriceX96,
      state.amountIn,
      state.amountOut,
      state.feeAmount
    ) = SwapMath.computeSwapStep(
      sqrtPriceX96,
      (
        zeroForOne
          ? sqrtPriceX96PoolLimit < sqrtPriceLimitX96
          : sqrtPriceX96PoolLimit > sqrtPriceLimitX96
      )
        ? sqrtPriceLimitX96
        : sqrtPriceX96PoolLimit,
      liquidity,
      amountSpecified,
      fee
    );

    // 更新池子价格
    sqrtPriceX96 = state.sqrtPriceX96;
    tick = TickMath.getTickAtSqrtPrice(state.sqrtPriceX96);

    // 累加手续费
    state.feeGrowthGlobalX128 += FullMath.mulDiv(
      state.feeAmount,
      FixedPoint128.Q128,
      liquidity
    );

    // 更新全局手续费
    if (zeroForOne) {
      feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
    } else {
      feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
    }

    // 更新剩余量和计算量
    if (exactInput) {
      state.amountSpecifiedRemaining -= (state.amountIn + state.feeAmount)
        .toInt256();
      state.amountCalculated = state.amountCalculated.sub(
        state.amountOut.toInt256()
      );
    } else {
      state.amountSpecifiedRemaining += state.amountOut.toInt256();
      state.amountCalculated = state.amountCalculated.add(
        (state.amountIn + state.feeAmount).toInt256()
      );
    }

    // 确定最终的 amount0 和 amount1
    (amount0, amount1) = zeroForOne == exactInput
      ? (
        amountSpecified - state.amountSpecifiedRemaining,
        state.amountCalculated
      )
      : (
        state.amountCalculated,
        amountSpecified - state.amountSpecifiedRemaining
      );

    // 回调收钱 + 转出付钱
    if (zeroForOne) {
      uint256 balance0Before = balance0();
      ISwapCallback(msg.sender).swapCallback(amount0, amount1, data);
      require(balance0Before.add(uint256(amount0)) <= balance0(), "IIA");

      if (amount1 < 0)
        TransferHelper.safeTransfer(
          token1,
          recipient,
          uint256(-amount1)
        );
    } else {
      uint256 balance1Before = balance1();
      ISwapCallback(msg.sender).swapCallback(amount0, amount1, data);
      require(balance1Before.add(uint256(amount1)) <= balance1(), "IIA");

      if (amount0 < 0)
        TransferHelper.safeTransfer(
          token0,
          recipient,
          uint256(-amount0)
        );
    }

    emit Swap(
      msg.sender,
      recipient,
      amount0,
      amount1,
      sqrtPriceX96,
      liquidity,
      tick
    );

  }
}
