Build a subgraph + adapter for Aave V3 to track user's net supplied amount of a specific block (get last block of every hour)

for this task we are tracking ETH , USDC , USDT on Arbitrum chain.

You can find the contracts here : https://docs.aave.com/developers/deployed-contracts/v3-mainnet/arbitrum

net supplied amount = total supplied - total borrowed
(Net supplied amount can be negative since cross borrowing is allowed)

The following scenarios should also be factored in:
1) Interest earned / accrued from supplying + borrowing 
2) Mint / Redeem / Borrow / Repay / Liquidation/Transfers(user A transfers aToken to user B)

The output csv file should contain the following [you can refer to the table at the bottom for reference]

1) block_number
2) timestamp
3) owner_address
4) token_symbol [ETH / USDC / USDT] (optional)
5) token_address (underlying reserve token)
6) token_amount (underlying reserve token balance)
