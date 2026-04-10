import { expect } from "chai";
import { ethers } from "hardhat";

describe("MNToken", function () {
  it("应该正确设置代币名称和符号", async function () {
    const MNToken = await ethers.getContractFactory("MNToken");

    const token = await MNToken.deploy("Micky Dollar A", "MKA");

    expect(await token.name()).to.equal("Micky Dollar A");

    expect(await token.symbol()).to.equal("MKA");
  });

  it("应该能铸造代币", async function () {
    const [owner] = await ethers.getSigners();
    const MNToken = await ethers.getContractFactory("MNToken");
    const token = await MNToken.deploy("Micky Dollar A", "MKA");

    const amount = ethers.parseEther("1000");
    await token.mint(owner.address, amount);

    expect(await token.balanceOf(owner.address)).to.equal(amount);
  });
});
