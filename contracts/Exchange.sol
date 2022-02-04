//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRegistry {
  function getExchange(address _tokenAddress) external view returns (address);
}

contract Exchange is ERC20 {

  address public tokenAddress;
  address public registryAddress;

  constructor(address _token) ERC20("Lp Token", "LP") {
    require(_token != address(0), "Invalid token");
    tokenAddress = _token;
    registryAddress = msg.sender;
  }

  function addLiquidityRate() public view returns (uint256) {
    uint256 ethReserve = address(this).balance;
    uint256 tokenReserve = getReserve();
    return (tokenReserve * 10**18) / ethReserve;
  }

  function addLiquidity(uint256 _tokenAmount) public payable returns(uint256) {
    uint256 mintedTokens;

    if (totalSupply() == 0) {
      mintedTokens = address(this).balance;
    } else {
      uint256 ethReserve = address(this).balance - msg.value;
      uint256 tokenReserve = getReserve();

      uint256 correctTokenAmount = (msg.value * tokenReserve) / ethReserve;
      require(_tokenAmount >= correctTokenAmount, "Incorrect token/eth ratio");

      mintedTokens = (msg.value * totalSupply()) / ethReserve;
    }

    IERC20 token = IERC20(tokenAddress);
    token.transferFrom(msg.sender, address(this), _tokenAmount);

    _mint(msg.sender, mintedTokens);
    return mintedTokens;
  }

  function removeLiquidity(uint256 _amount) public returns (uint256, uint256) {
    require(_amount > 0, "invalid amount");

    uint256 ethAmount = (address(this).balance * _amount) / totalSupply();
    uint256 tokenAmount = (getReserve() * _amount) / totalSupply();

    _burn(msg.sender, _amount);

    payable(msg.sender).transfer(ethAmount);
    IERC20(tokenAddress).transfer(msg.sender, tokenAmount);

    return (ethAmount, tokenAmount);
  }

  function getReserve() public view returns (uint256) {
    return IERC20(tokenAddress).balanceOf(address(this));
  }

  function getAmount(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) private pure returns (uint256) {
    require(inputReserve > 0 && outputReserve > 0, "Invalid reserves");

    uint256 fee = 99; // 1%
    uint256 inputAmountWithFee = inputAmount * fee;
    uint256 numerator = inputAmountWithFee * outputReserve;
    uint256 denominator = (inputReserve * 100) + inputAmountWithFee;
    return numerator / denominator;
  }

  function getTokenAmount(uint256 _ethSold) public view returns (uint256) {
    require(_ethSold > 0, "Invalid ETH amount");
    uint256 tokenReserve = getReserve();
    return getAmount(_ethSold, address(this).balance, tokenReserve);
  }

  function getEthAmount(uint256 _tokenSold) public view returns (uint256) {
    require(_tokenSold > 0, "Invalid token amount");
    uint256 tokenReserve = getReserve();
    return getAmount(_tokenSold, tokenReserve, address(this).balance);
  }

  function ethToToken(uint256 _minTokens, address recipient) private {
    uint256 tokenReserve = getReserve();

    uint256 tokensBought = getAmount(
      msg.value,
      address(this).balance - msg.value,
      tokenReserve
    );

    require(tokensBought >= _minTokens, "insufficient output amount");
    IERC20(tokenAddress).transfer(recipient, tokensBought);
  }

  function ethToTokenSwap(uint256 _minTokens) public payable {
    ethToToken(_minTokens, msg.sender);
  }

  function ethToTokenTransfer(uint256 _minTokens, address _recipient) public payable {
    ethToToken(_minTokens, _recipient);
  }

  function tokenToEthSwap(uint256 _tokensSold, uint256 _minEth) public {
    uint256 tokenReserve = getReserve();
    uint256 ethBought = getAmount(
      _tokensSold,
      tokenReserve,
      address(this).balance
    );

    require(ethBought >= _minEth, "insufficient output amount");

    IERC20(tokenAddress).transferFrom(
      msg.sender,
      address(this),
      _tokensSold
    );

    payable(msg.sender).transfer(ethBought);
  }

  function tokenToTokenSwap(
      uint256 _tokensSold,
      uint256 _minTokensBought,
      address _tokenAddress
  ) public {
      address exchangeAddress = IRegistry(registryAddress).getExchange(
          _tokenAddress
      );

      require(exchangeAddress != address(this), "invalid exchange address");
      require(exchangeAddress != address(0), "there's no exchange for wanted token");

      uint256 tokenReserve = getReserve();

      uint256 ethBought = getAmount(
          _tokensSold,
          tokenReserve,
          address(this).balance
      );

      IERC20(tokenAddress).transferFrom(
          msg.sender,
          address(this),
          _tokensSold
      );

      Exchange(exchangeAddress).ethToTokenTransfer{value: ethBought}(
          _minTokensBought,
          msg.sender
      );
  }

  function getTokenToTokenAmount(uint256 _tokenSold, address _tokenAddress) public view returns (uint256) {
    address exchangeAddress = IRegistry(registryAddress).getExchange(_tokenAddress);
    require(exchangeAddress != address(this), "invalid exchange address");
    require(exchangeAddress != address(0), "there's no exchange for wanted token");

    uint256 ethAmount = getEthAmount(_tokenSold);
    return Exchange(exchangeAddress).getTokenAmount(ethAmount);
  }

}
