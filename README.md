## Introduction

The aim of this project is to understand the basic functionality of an AMM (Automatic Market Maker).

The contracts are based on Uniswap v1.

I've made a frontend to interact and test this project, which you can find here: https://github.com/EperezOk/amm-frontend

## A closer look on how the AMM works

For this explanation I will refer to ETH as the native blockchain currency, but these contracts could also be deployed to any EVM blockchain.

This AMM consists of 2 contracts:

- **Registry:** creates and keeps track of every pool (each pool consists of a pair ERC20 token / ETH). At most one pool is created for a given pair.

- **Exchange:** represents a pool. Handles the add and remove liquidity functionality, as well as the swaps between ETH and the ERC20 token of that pool.

When a pool is created, the first liquidity provider can set any ratio between the pair of tokens. After that, the ratio will be calculated based on the reserves of each token.

Liquidity providers will be given "LP tokens", which they can use whenever they want to get their liquidity back from the pool. This LP token is unique for each pool, and the pool **is** in fact a token (Exchange inherits from ERC20).

LP tokens represent the participation (percentage of the reserves) a user has contributed to the pool.

When a user wants to use the pool to make a swap, a 1% fee will be applied to the input amount, and will be added to the pool reserves.
Note that liquidity providers will indirectly be getting their part of that fee as they own a part of the pool reserves, which will be growing because of the fees. 

To determine the price of a token relative to its counterpart in the pool, we use a "Bonding Curve".
In this AMM, the bonding curve is given by the function **X * Y = K**, where X and Y represent the reserves of each token of the pool and K is a constant.

#### Brief explanation of the bonding curve implementation in `getAmount()` function at `Exchange.sol`

When making a "swap", let dX = input token amount and dY = output token amount.

We want to determine dY to know the amount of token we have to give to the user given their input amount.

Since K is a constant, this equation must be true:

> (X + dX) * (Y - dY) = K

Isolating dY from the equation:

> dY = Y - K / (X + dX) , and K = X * Y
> 
> dY = Y - XY / (X + dX)
> 
> dY = (YX + Y * dX - XY) / (X + dX) 
> 
> dY = Y * dX / (X + dx) 
> 
> outputAmount = (outputReserve * inputAmount) / (inputReserve + inputAmount)

#### Swapping between 2 ERC20 tokens

Since every pool has ETH as one of its tokens, we cannot make a swap between 2 ERC20 tokens directly.

For that we need to connect two Exchanges using the Registry.

For example, if we have an Exchange for DAI / ETH and another one for BTC / ETH and we want to trade DAI / BTC, the DAI / ETH pool has to:

**1.** Change DAI for ETH

**2.** Get the BTC / ETH pool and swap the ETH obtained in the previous step for BTC

**3.** Send the BTC to the user
