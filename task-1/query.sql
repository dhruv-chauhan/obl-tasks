-- https://dune.com/queries/3748299/6304400/

WITH
    tokens AS (
        select
            token0,
            token1
        from uniswap_v3_ethereum.Factory_evt_PoolCreated
        where pool=0xe8c6c9227491C0a8156A0106A0204d881BB7E531
    )
    , events AS (
        select 
            *,
            SUM(amount0) OVER (order by evt_block_time, evt_index) as cum_amount0,
            SUM(amount1) OVER (order by evt_block_time, evt_index) as cum_amount1,
            date_trunc('day', evt_block_time) as day 
        from query_3748231
    )
    , events_grouped AS (
        select 
            *,
            ROW_NUMBER() OVER(PARTITION by day order by evt_block_time desc, evt_index desc) as row_number
        from events
    )
    , eod_liquidity AS (
        select *
        from events_grouped, tokens
        where row_number = 1
    )
    , eod_prices AS (
        select * from query_3748289
    )

select
    l.day as date,
    0xe8c6c9227491C0a8156A0106A0204d881BB7E531 as pool_contract_address,
    (l.cum_amount0 / power(10, p0.decimals) * p0.price) + (l.cum_amount1 / power(10, p1.decimals) * p1.price) as tvl_in_usd
from eod_liquidity l
left join eod_prices p0
    on l.token0 = p0.contract_address
    and l.day = p0.day
left join eod_prices p1
    on l.token0 = p1.contract_address
    and l.day = p1.day
order by l.day desc
