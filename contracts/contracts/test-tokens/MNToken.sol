// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 测试代币合约，用户DEX交易测试
// 任何人都可以 mint 代币
contract MNToken is ERC20 {
  constructor(
    string memory name,
    string memory symbol
  ) ERC20(name, symbol) {

  }

  // 铸造代币给指定地址
  // recipient 接受地址
  // quantity： 铸造数量（单位是wei， 一个代币 = 10^18wei)
  function mint(
    address recipient,
    uint256 quantity
  ) public {
    require(quantity > 0, 'quantity must be greater than 0');
    _mint(recipient, quantity);
  }
}
