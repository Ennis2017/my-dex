# 学习问答记录

## Step 1: Hardhat 项目初始化

### Q: bun.lock 是什么文件，我需要关心吗？

跟 `package-lock.json`（npm）或 `pnpm-lock.yaml` 一样，是依赖锁定文件。它记录每个包的精确版本，确保团队所有人安装的依赖版本一致。不需要手动编辑，但要提交到 git。

### Q: bun 的初始化为什么会在当前目录下生成一个 CLAUDE.md 的文件？

这是 bun 自动生成的，不是项目文档。bun 检测到在用 Claude Code，就自动生成了一份 bun 的使用指南。对我们没用（我们用 Hardhat 而不是 Bun.serve），直接删掉。

### Q: @nomicfoundation/hardhat-toolbox 和 hardhat 包有什么区别？ts-node 是什么包？

- **hardhat**：核心包，提供编译、部署、测试智能合约的基础能力。
- **@nomicfoundation/hardhat-toolbox**：官方"全家桶"插件包，一次性装好 ethers.js、chai、typechain、solidity-coverage、gas-reporter 等常用工具。不装它就要一个一个手动装。
- **ts-node**：让 Node.js 直接运行 TypeScript 文件（不需要先编译成 JS）。Hardhat 的配置文件 `hardhat.config.ts` 需要它来执行。

### Q: bunx 是什么意思？

`bunx` = bun 版的 `npx`。作用是临时执行一个包的命令行工具，不需要全局安装。`bunx hardhat init` 就是运行项目里安装的 hardhat 的 `init` 命令。

### Q: 为什么要有 bunx/npx 这种临时命令？有什么好处吗？

1. 有些工具只在初始化时用一次（如 `hardhat init`、`create-next-app`），没必要全局安装占空间。
2. 更重要的是避免版本不一致：直接跑 `hardhat init` 会用全局版本，但项目里装的版本可能不同。`bunx` 保证用的是当前项目 `node_modules` 里的版本。

### Q: Hardhat 2.x vs 3.x 版本问题？

参考项目用的是 Hardhat `2.22.3`。建议学 2.x，因为：生态更成熟、教程更多、参考项目对照方便。核心概念一样，以后迁移 3.x 很容易。用 `bun add -D hardhat@^2.22.3` 指定 2.x 版本即可。

### 报错: Error HH20 - ESM 不兼容

**报错信息**：`Your project is an ESM project (you have "type": "module" set in your package.json) and you are trying to initialize a TypeScript project. This is not supported yet.`

**原因**：`bun init` 在 `package.json` 中自动加了 `"type": "module"`，表示用 ESM（`import/export`）模式。但 Hardhat 2.x 的配置文件用 CommonJS（`require/module.exports`），两者不兼容。

**解决**：从 `package.json` 中删除 `"type": "module"` 这一行，重新执行 `bunx hardhat init`。

### 报错: tsconfig.json 已存在

**报错信息**：`We couldn't initialize the sample project because this file already exists: tsconfig.json`

**原因**：`bun init` 已生成了 `tsconfig.json`，与 Hardhat 要生成的冲突。

**解决**：删除 `tsconfig.json` 后重新执行 `bunx hardhat init`。

### 报错: hardhat-toolbox 版本不兼容

**报错信息**：`You installed the latest version of @nomicfoundation/hardhat-toolbox, which does not work with Hardhat 2 nor 3.`

**原因**：`@nomicfoundation/hardhat-toolbox@latest` 是过渡版本，不兼容任何 Hardhat 版本。Hardhat 2 需要用 `hh2` 标签的版本。

**解决**：执行 `bun add -D @nomicfoundation/hardhat-toolbox@hh2` 安装兼容版本。

### 报错: TS5011 rootDir 未设置

**报错信息**：`The common source directory of 'tsconfig.json' is './test'. The 'rootDir' setting must be explicitly set.`

**原因**：TypeScript 编译器找不到 `rootDir` 配置，无法确定源文件的根目录。

**解决**：在 `tsconfig.json` 的 `compilerOptions` 中添加 `"rootDir": "."`。

### Q: contracts/contracts 和 contracts/artifacts 有什么区别？

- `contracts/contracts/`：手写的 Solidity 源代码（类比前端的 `.tsx` 源文件）
- `contracts/artifacts/`：`bunx hardhat compile` 编译后的产物（类比前端的 `dist/` 打包目录），包含 ABI（合约接口描述，前端靠它调合约）和字节码（部署到链上的机器码）

外层 `contracts/` 是项目名，内层 `contracts/` 是 Hardhat 约定的源码目录。

### Q: 部署脚本 ignition/modules/Lock.ts 找的是 contracts/contracts/ 还是 artifacts/？

都用到。部署流程是：
1. 先找 `contracts/contracts/Lock.sol` 编译（如果还没编译或源码有改动）
2. 再从 `artifacts/` 拿编译好的字节码部署到链上

部署脚本不直接读 `.sol`，读的是 artifacts 里的字节码。但 Hardhat 自动先编译再部署，感觉像直接部署了源码。类比前端：`npm run build && npm run deploy` 合成一步。

### Q: 为什么用 libraries/ 而不是 utils/？

Solidity 中 `library` 是语言级关键字（跟 `contract` 同级），表示无状态、纯函数的工具集合。`libraries/` 目录是跟语言特性对应的命名约定，类似 React 项目里 `hooks/` 放 Hook、`components/` 放组件。

### Q: 执行部署命令时会自动编译吗？

是的。部署命令（`bunx hardhat ignition deploy`）会自动编译再部署，不需要手动先跑 `bunx hardhat compile`。单独用 `compile` 的场景主要是写合约过程中检查语法错误，类似前端的 `tsc --noEmit`。

## Step 2: 编写 ERC20 测试代币

### 报错: Error HH411 - 库未安装

**报错信息**：`The library @openzipplin/contract, imported from contracts/test-tokens/MNToken.sol, is not installed.`

**原因**：import 路径拼写错误。正确包名是 `@openzeppelin/contracts`（注意 zeppelin 和 contracts 复数）。

**解决**：修改 import 语句为 `import "@openzeppelin/contracts/token/ERC20/ERC20.sol";`。

### 报错: ParserError - 缺少分号

**报错信息**：`Expected ';' but got identifier → _mint(recipient, quantity)`

**原因**：Solidity 每条语句结尾必须加分号（跟 JS 不同，Solidity 强制要求）。

**解决**：在 `_mint(recipient, quantity)` 后加 `;`。Solidity 里所有语句都要加分号（`require`、`_mint`、`emit` 等），除了 `function`、`if`、`for` 这些带 `{}` 的结构。

### Q: MNToken.sol 里没有定义 `_mint` 函数，为什么能用？

通过 `contract MNToken is ERC20` 继承了 OpenZeppelin 的 ERC20 合约。`is` 就是 Solidity 的继承语法，等同于 TypeScript 的 `extends`。继承后自动拥有 ERC20 的所有函数（`_mint`、`transfer`、`approve`、`balanceOf` 等）。`import` 只是告诉编译器去哪找 ERC20 的定义，`is` 才是真正的继承。

### Q: Solidity import 没有显式导入 ERC20 也能直接用？

Solidity 和 TypeScript 的 import 机制不同。Solidity 的 `import "path.sol"` 默认导入该文件里的所有合约，不需要写 `{ ERC20 }`。也支持显式写法 `import { ERC20 } from "path.sol"`，效果一样，只是更清晰。

### Q: expect 是什么？chai 从哪来？package 里没这个包？

- `expect` 是 chai 断言库提供的函数，读起来像英语：`expect(A).to.equal(B)` → "期望 A 等于 B"
- `chai` 不需要单独安装，它包含在 `@nomicfoundation/hardhat-toolbox` 全家桶里
- 常用断言：`to.equal()`（相等）、`to.be.revertedWith()`（期望交易回滚）

### Q: 为什么 TypeScript 测试文件能测试 Solidity 合约？

TS 不是直接运行 `.sol`。流程是：
1. Hardhat 把 `.sol` 编译成 ABI + 字节码（在 artifacts/ 里）
2. `ethers.getContractFactory()` 读取 ABI，生成 JS 可调用的合约对象
3. `deploy()` / `mint()` 等调用发送到 Hardhat 内置的本地测试链执行
4. TS 拿到返回值，用 chai 做断言

TypeScript 是调用者，合约跑在本地测试链上，两者通过 ethers.js 桥接，类似前端通过 API 调后端。

### Q: 为什么能直接 `import { expect } from "chai"` 而不是从 hardhat-toolbox 导入？

`hardhat-toolbox` 安装时会把 `chai` 作为依赖一起装进 `node_modules/`。TypeScript 的 import 只要 `node_modules/` 里有这个包就能引用，不管是直接装的还是被别的包间接带进来的。类比：装了 shadcn/ui 后可以直接 import radix-ui 的组件。

### Q: chai 是专门测 Solidity 的吗？和其他测试框架的 expect 有什么区别？

chai 是通用的 JS/TS 断言库，不是 Solidity 专用。常见的 expect 来源：Jest（内置）、Vitest（内置）、Mocha+Chai（Hardhat 用这套）、Bun Test（内置）。写法几乎一样，只是来自不同的包。Hardhat 选 Mocha+Chai 是历史原因。

## Step 3: 编写 Pool 合约

### Q: 为什么要单独拆 interfaces/ 目录？不能写在 contract 文件里吗？

技术上可以，但分开的好处：①合约间互相调用只需 import 接口而非完整实现，编译更快；②避免循环依赖（Pool 依赖 Factory，Factory 又部署 Pool）；③行业惯例（Uniswap、OpenZeppelin 等都这样组织）。类似 TS 把 type 抽到 types/ 目录。

### Q: 为什么接口名要加 `I` 前缀？定义完怎么用？

`I` 前缀是命名约定（来自 C#/Java），一眼区分 `IPool`（接口）和 `Pool`（实现），不加也能编译。

用法两种：①实现接口：`contract Pool is IPool { ... }`，必须实现所有声明的函数；②调用其他合约：`IPool(poolAddress).swap(...)`，把地址转型成接口就能调用函数，不需要 import 完整实现。

### Q: 只知道接口怎么能调用？多个合约实现同一接口怎么办？

Solidity 和 TS 根本不同：合约部署后是链上的独立程序，有固定地址。`IPool(0x1234)` 不是创建实例，而是说"0x1234 这个地址上的合约符合 IPool 接口"，调用时本质是向该地址发送 ABI 编码的消息。多个合约实现同一接口完全没问题，传不同地址就调不同合约。接口就像电话簿格式，地址就是具体的电话号码。

### Q: bunx hardhat compile 在哪个目录跑？

始终在 `contracts/` 目录（有 `hardhat.config.ts` 的那层）。

### Q: artifacts 目录下的东西可以删吗？增量还是全量更新？

可以随时删，`bunx hardhat clean` 会清空 artifacts/cache/typechain-types。下次编译全量重新生成。有 cache 时是增量编译（只编译改动文件），clean 后是全量编译。artifacts 里的 @openzeppelin 是编译时自动生成的，不是手动加的。

### Q: 提示 Contract "Pool" should be marked as abstract 是什么意思？

说明 Pool 还没实现 IPool 接口里的所有函数。因为我们分步写，`mint`/`burn`/`collect`/`swap` 还没写，编译器提醒"合约不完整"。这是警告不是报错，等所有函数写完就消失了。

### 报错: Undeclared identifier feeGrowthGlobal1X128

**报错信息**：`DeclarationError: Undeclared identifier. feeGrowthGlobal1X128`

**原因**：在 `_modifyPosition` 函数中使用了 `feeGrowthGlobal0X128` 和 `feeGrowthGlobal1X128`，但忘记在状态变量区域声明它们。

**解决**：在 `liquidity` 变量后面添加 `uint256 public override feeGrowthGlobal0X128;` 和 `uint256 public override feeGrowthGlobal1X128;`。

### Q: Solidity 的 struct 类比 TypeScript 的 interface？

差不多，但 struct 运行时存在（占用链上存储），TS 的 interface 编译后消失。Solidity 的 struct = TS 的 interface + 实际存储。

### Q: override 什么时候加？合约能新增自己的变量/函数吗？

接口里声明了的函数/变量，实现时必须加 `override`。合约自己新增的变量/函数不需要也不能加 `override`（接口里没有的东西加了会报错）。`override` = "我在实现接口里声明的这个东西"。

### Q: 数学库是 Uniswap 官方标准的吗？

是的，几乎都来自 Uniswap V3 官方仓库（uniswap-v3-core 和 v3-periphery），经过审计。BitMath 用了 Solady 的优化版，CustomRevert 来自 Uniswap V4。整个 DeFi 行业的 AMM 项目大多复用 Uniswap 的数学库。

### Q: SPDX-License-Identifier 是什么？

声明文件的开源许可证，Solidity 编译器强制要求第一行写，不写会有警告。不影响代码功能，是法律层面声明。常用 `MIT`（宽松）或 `GPL-2.0-or-later`（Uniswap 用的，衍生代码需保持一致）。

### Q: 写合约需要先写 interface 吗？

不是必须的，小项目可以直接写 contract。多合约互相调用的项目才需要接口来解耦。

### Q: @notice、@param 是什么语法？

NatSpec（Natural Specification），Solidity 的官方注释规范，类似 JSDoc。纯注释不影响编译，让代码更好读，不写也没问题。

### Q: tokensOwed 中的 Owed 是什么意思？

`owed` 是英文"欠的、应付的"。`tokensOwed0` = 池子欠你的 token0 数量。burn 时记账到 tokensOwed，collect 时真正转出清零。

### Q: 测试中重复的部署代码能统一吗？

用 `beforeEach` 提取。它在每个 `it` 执行前自动运行，保证每个测试用例拿到"干净"的合约状态。用 `beforeEach` 而不是 `before`，是因为每个测试需要独立的状态互不干扰（类似 React 测试里每个 test 都重新 render）。
