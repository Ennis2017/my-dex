// chai 是一个断言库（assertion library），用来判断"结果是否符合预期"
// expect 是 chai 提供的断言函数，读起来像英语：expect(A).to.equal(B) → "期望 A 等于 B"
// chai 不需要手动安装，它包含在 @nomicfoundation/hardhat-toolbox 全家桶里
import { expect } from "chai";

// ethers 是以太坊交互库，从 hardhat 导入的版本会自动连接到 Hardhat 的本地测试链
// 它提供了部署合约、调用合约函数、获取账户等能力
import { ethers } from "hardhat";

describe("MNToken", function () {
  // 在 describe 块内声明共享变量，让所有 it 都能访问
  let token: any;
  let owner: any;

  // beforeEach 在每个 it 执行前都会运行
  // 为什么用 beforeEach 而不是 before？
  // 因为每个测试用例需要一个"干净"的合约状态，互不干扰
  // 类似 React 测试里每个 test 都重新 render 组件
  beforeEach(async function () {
    [owner] = await ethers.getSigners();
    const MNToken = await ethers.getContractFactory("MNToken");
    token = await MNToken.deploy("Micky Dollar A", "MKA");
  });

  it("应该正确设置代币名称和符号", async function () {
    expect(await token.name()).to.equal("Micky Dollar A");
    expect(await token.symbol()).to.equal("MKA");
  });

  it("应该能铸造代币", async function () {
    const amount = ethers.parseEther("1000");
    await token.mint(owner.address, amount);
    expect(await token.balanceOf(owner.address)).to.equal(amount);
  });

  it("铸造数量为 0 应该失败", async function () {
    await expect(token.mint(owner.address, 0)).to.be.revertedWith("error");
  });
});
