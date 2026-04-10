# Pool.sol — Swap 函数详解

## 一、Swap 做了什么？

用户拿 token0 换 token1（或反过来），池子根据当前价格和流动性计算兑换数量，同时收取手续费、更新价格。

## 二、核心参数

```solidity
function swap(
    address recipient,          // 收到输出代币的地址
    bool zeroForOne,            // true = 用token0换token1，false = 反过来
    int256 amountSpecified,     // 正数 = exact input，负数 = exact output
    uint160 sqrtPriceLimitX96,  // 价格滑点保护上/下限
    bytes calldata data         // 回调数据
)
```

### zeroForOne 方向理解

| zeroForOne | 用户操作 | 池子变化 | 价格走向 |
|---|---|---|---|
| `true` | 卖 token0 买 token1 | 收到更多 token0 | 价格**下降** |
| `false` | 卖 token1 买 token0 | 收到更多 token1 | 价格**上升** |

> 价格 = token1/token0，池子里 token0 越多越便宜，所以 zeroForOne=true 时价格下降。

### amountSpecified 正负含义

| 值 | 含义 | 场景 |
|---|---|---|
| `> 0` | exact input（精确输入） | 用户说："我要花 100 USDC" |
| `< 0` | exact output（精确输出） | 用户说："我要得到 0.05 ETH" |

## 三、sqrtPriceLimitX96 — 滑点保护

用户提交交易到链上执行之间有延迟，价格可能已经变了。这个参数限制价格最多滑到哪里：

- `zeroForOne = true`（价格下降）→ `sqrtPriceLimitX96` 是**价格下限**
- `zeroForOne = false`（价格上升）→ `sqrtPriceLimitX96` 是**价格上限**

require 校验逻辑：

```solidity
zeroForOne
    ? sqrtPriceLimitX96 < sqrtPriceX96 && sqrtPriceLimitX96 > MIN_SQRT_PRICE
    : sqrtPriceLimitX96 > sqrtPriceX96 && sqrtPriceLimitX96 < MAX_SQRT_PRICE
```

含义：
- zeroForOne=true：limit 必须**低于**当前价格（因为价格要往下走），且不能低于最小值
- zeroForOne=false：limit 必须**高于**当前价格（因为价格要往上走），且不能高于最大值

## 四、SwapState — 计算过程的临时状态

```solidity
struct SwapState {
    int256 amountSpecifiedRemaining;  // 还剩多少没成交
    int256 amountCalculated;          // 已算出的另一边数量
    uint160 sqrtPriceX96;             // 当前计算到的价格
    uint256 feeGrowthGlobalX128;      // 手续费累计值
    uint256 amountIn;                 // computeSwapStep 返回的输入量
    uint256 amountOut;                // computeSwapStep 返回的输出量
    uint256 feeAmount;                // computeSwapStep 返回的手续费
}
```

> 我们简化版只有一个价格区间，所以 swap 只需要调用一次 `computeSwapStep`。  
> 真正的 Uniswap V3 有多个 tick 区间，需要 while 循环逐个区间计算。

## 五、执行流程（全局视角）

```
用户调 swap(zeroForOne=true, amount=100 token0)
    │
    ▼
① 参数校验（amountSpecified != 0，价格限制合法）
    │
    ▼
② 初始化 SwapState（把当前池子状态拷贝到临时变量）
    │
    ▼
③ 计算目标价格上下限（取 用户limit 和 池子边界 的更严格者）
    │
    ▼
④ SwapMath.computeSwapStep() 核心计算
   → 算出：新价格、输入量、输出量、手续费
    │
    ▼
⑤ 更新池子价格（sqrtPriceX96、tick）
    │
    ▼
⑥ 累加手续费到 feeGrowthGlobalX128
    │
    ▼
⑦ 更新 amountSpecifiedRemaining 和 amountCalculated
    │
    ▼
⑧ 确定最终 amount0 和 amount1（一正一负）
    │
    ▼
⑨ 回调 swapCallback 让调用者转入输入代币 + 验证到账
    │
    ▼
⑩ 转出输出代币给 recipient
    │
    ▼
⑪ emit Swap 事件
```

## 六、SwapMath.computeSwapStep() — 核心计算

这个函数由库完成，我们只需要知道输入输出：

```
输入：当前价格、目标价格、流动性、待成交量、费率
输出：新价格、实际输入量、实际输出量、手续费
```

它内部做了：
1. 从输入量中扣除手续费
2. 根据 AMM 曲线算出价格移动多远
3. 如果移动到目标价格还没用完输入量 → 价格停在目标价，剩余量不成交
4. 如果输入量在到达目标价前就用完了 → 价格停在中间位置

## 七、目标价格的确定

```solidity
// 池子自己的边界
uint160 sqrtPriceX96PoolLimit = zeroForOne
    ? TickMath.getSqrtPriceAtTick(tickLower)   // 价格下降不能低于 tickLower
    : TickMath.getSqrtPriceAtTick(tickUpper);  // 价格上升不能高于 tickUpper

// 传给 computeSwapStep 的目标价 = 取两个限制中更严格的那个
sqrtPriceTarget = (
    zeroForOne
        ? sqrtPriceX96PoolLimit < sqrtPriceLimitX96  // 池子下限更高 → 用用户limit
        : sqrtPriceX96PoolLimit > sqrtPriceLimitX96  // 池子上限更低 → 用用户limit
)
    ? sqrtPriceLimitX96
    : sqrtPriceX96PoolLimit;
```

简单说：**哪个限制先到就用哪个**。

## 八、手续费怎么收

手续费从**输入代币**中扣除：

```
用户要换 100 token0 → 实际参与兑换的 = 100 × (1 - fee/1e6)
手续费 = 100 × fee/1e6
```

手续费累加到全局累计值：

```solidity
feeGrowthGlobalX128 += feeAmount × Q128 / liquidity
```

这就是 LP 在 burn/collect 时通过 `feeGrowthGlobal - feeGrowthInsideLast` 计算自己份额的基础。

## 九、amount0 和 amount1 最终确定

这是最绕的部分。swap 结束后需要确定 amount0 和 amount1（从池子视角，正=收入，负=支出）：

```solidity
(amount0, amount1) = zeroForOne == exactInput
    ? (amountSpecified - amountSpecifiedRemaining, amountCalculated)
    : (amountCalculated, amountSpecified - amountSpecifiedRemaining);
```

### 四种组合分析

| zeroForOne | exactInput | amount0 来源 | amount1 来源 |
|---|---|---|---|
| true + exact input | ✅ | `specified - remaining`（正，池子收 token0） | `calculated`（负，池子付 token1） |
| true + exact output | ❌ | `calculated`（正，池子收 token0） | `specified - remaining`（负，池子付 token1） |
| false + exact input | ❌ | `calculated`（负，池子付 token0） | `specified - remaining`（正，池子收 token1） |
| false + exact output | ✅ | `specified - remaining`（负，池子付 token0） | `calculated`（正，池子收 token1） |

核心逻辑：`zeroForOne == exactInput` 时，token0 是"指定方"（用 specified - remaining），token1 是"计算方"。

## 十、回调模式（先回调收钱 → 再转出付钱）

```solidity
if (zeroForOne) {
    // 用户卖 token0 → 池子需要收 token0
    uint256 balance0Before = balance0();
    ISwapCallback(msg.sender).swapCallback(amount0, amount1, data);
    require(balance0Before + amount0 <= balance0(), "IIA");  // 验证到账

    // 池子付 token1 给用户
    if (amount1 < 0)
        TransferHelper.safeTransfer(token1, recipient, uint256(-amount1));
} else {
    // 用户卖 token1 → 池子需要收 token1
    uint256 balance1Before = balance1();
    ISwapCallback(msg.sender).swapCallback(amount0, amount1, data);
    require(balance1Before + amount1 <= balance1(), "IIA");

    // 池子付 token0 给用户
    if (amount0 < 0)
        TransferHelper.safeTransfer(token0, recipient, uint256(-amount0));
}
```

注意：这里的顺序是**先回调收钱，再转出付钱**。跟 Uniswap V3 原版（先付后收，支持闪电兑换）不同，我们简化版更安全直接。

## 十一、去掉 abstract

swap 是 Pool 合约中最后一个需要实现的函数。写完 swap 后，合约所有接口方法都已实现，需要把 `abstract contract Pool` 改为 `contract Pool`。
