-- https://dune.com/queries/3748289/6304385/

WITH
    tokens AS (
        select
            token0,
            token1
        from uniswap_v3_ethereum.Factory_evt_PoolCreated
        where pool=0xe8c6c9227491C0a8156A0106A0204d881BB7E531
    )
    , prices AS (
        select 
            minute,
            blockchain,
            contract_address,
            decimals,
            symbol,
            price,
            date_trunc('day', minute) as day
        from prices.usd
        where blockchain='ethereum'
        and contract_address in (
            select token0 from tokens
            union
            select token1 from tokens
        )
    )
    , prices_grouped AS (
        select 
            *,
            ROW_NUMBER() OVER(PARTITION by day, contract_address order by minute desc) as row_number
        from prices
    )
    , eod_prices AS (
        select *
        from prices_grouped
        where row_number = 1
    )
    
select * from eod_prices
