# 学习进度

## 教学路线图

### Phase 1: 智能合约（Solidity + Hardhat）

| 步骤 | 内容 | 学习目标 | 状态 |
|------|------|---------|------|
| Step 1 | Hardhat 项目初始化 | Hardhat 工程结构、编译、本地节点 | 已完成 |
| Step 2 | 编写 ERC20 测试代币 | Solidity 基础、OpenZeppelin、合约测试 | 已完成 |
| Step 3 | 编写 Pool 合约（核心） | AMM 原理、集中流动性、tick/sqrtPrice 数学 | 已完成 |
| Step 4 | 编写 Factory + PoolManager | 工厂模式、CREATE2、合约间调用 | 未开始 |
| Step 5 | 编写 PositionManager | NFT 头寸、mint/burn/collect | 未开始 |
| Step 6 | 编写 SwapRouter | 交换路由、回调模式、报价函数 | 未开始 |
| Step 7 | 本地测试 + 部署到 Sepolia | Hardhat 测试、部署脚本、验证合约 | 未开始 |

### Phase 2: 前端（Next.js + wagmi）

| 步骤 | 内容 | 学习目标 | 状态 |
|------|------|---------|------|
| Step 8 | Next.js 项目初始化 | App Router、Tailwind、shadcn/ui | 未开始 |
| Step 9 | Web3 Provider 配置 | wagmi、viem、RainbowKit、钱包连接 | 未开始 |
| Step 10 | Swap 页面 | 合约读写、ERC20 approve、Token 兑换 | 未开始 |
| Step 11 | Pools 列表页 | 链上数据读取、Pool 信息展示 | 未开始 |
| Step 12 | 添加流动性页面 | 集中流动性 UI、价格区间选择、mint | 未开始 |
| Step 13 | Positions 页面 | 头寸管理、burn/collect 操作 | 未开始 |

### Phase 3: 联调与优化（可选）

| 步骤 | 内容 | 学习目标 | 状态 |
|------|------|---------|------|
| Step 14 | 前端连接自己的合约 | 端到端联调、合约地址管理 | 未开始 |
| Step 15 | 部署到测试网完整测试 | 真实环境调试、Gas 优化 | 未开始 |

## 当前进度

**当前阶段**：Phase 1 - 智能合约
**已完成**：Step 3 - Pool 合约（mint、burn、collect、swap 四个核心函数）
**下一步**：Step 4 - 编写 Factory + PoolManager
