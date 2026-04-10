# My DEX 项目

## 项目概述

基于 [DEX-Proj](/Users/mca/Desktop/Code/web3/DEX-Proj) 参考项目，从零构建一个简化版 DEX（去中心化交易所），学习 Uniswap V3 集中流动性 AMM 的核心设计。

## 参考项目

- 路径：`/Users/mca/Desktop/Code/web3/DEX-Proj`
- 包含：前端（Next.js）、后端（Go）、智能合约（Solidity/Hardhat）
- 已部署在 Sepolia 测试网

## 技术栈

- **合约**：Solidity + Hardhat（本地开发 + 测试 + 部署）
- **前端**：Next.js + React + TypeScript + Tailwind CSS + shadcn/ui
- **Web3**：wagmi + viem + RainbowKit
- **包管理**：bun

## 简化策略

| 参考项目 | 简化版 |
|---------|-------|
| Go 后端 + 数据库路由 | 直接调合约 quoteExactInput |
| Supabase/MySQL | 不用数据库，数据从链上读 |
| 多跳路由 | 只支持单跳直接交易对 |
| NFT 展示 / 代币 Release | 不做 |

## 开发规范

- commit message 使用中文
- 代码注释使用中文
- 使用 bun 管理依赖（不用 pnpm/npm/yarn）
- 遵循全局 CLAUDE.md 中的编码规范

## 文档维护规则

- 每次用户提出问题时，将问答记录追加到 `QA.md`（一问一答形式）
- 每次遇到报错时，将报错信息、原因和解决方式也追加到 `QA.md`
- 每次完成一个 Step 或 Phase 时，必须更新 `PROGRESS.md` 文档
- 每次让用户执行命令前，必须说明：命令的作用、执行后会生成/修改哪些文件、预期输出是什么
