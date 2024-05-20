Provide a Dune or Flipside query where you list the current liquidity providers of AAVE on Ethereum, the final dataset should include these columns:

1/ address of the liquidity provider 
2/ asset
3/ liquidity provided by the user in USD 

Hint:
You’ll need to factor in liquidation, interest earned etc.
You can filter out users with balance < $100 for each asset to optimize the query.
