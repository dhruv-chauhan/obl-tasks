-- https://dune.com/queries/3748231/6304292/

WITH
    tokens AS (
        select
            token0,
            token1
        from uniswap_v3_ethereum.Factory_evt_PoolCreated
        where pool=0xe8c6c9227491C0a8156A0106A0204d881BB7E531
    )
    , mints AS (
        select 
            contract_address,
            evt_tx_hash,
            evt_index,
            evt_block_time,
            evt_block_number,
            'Mint' as evt_name,
            amount0,
            amount1
        from uniswap_v3_ethereum.Pair_evt_Mint
        where contract_address=0xe8c6c9227491C0a8156A0106A0204d881BB7E531
    )
    , burns AS (
        select 
            contract_address,
            evt_tx_hash,
            evt_index,
            evt_block_time,
            evt_block_number,
            'Burn' as evt_name,
            -amount0 as amount0,
            -amount1 as amount1
        from uniswap_v3_ethereum.Pair_evt_Collect
        where contract_address=0xe8c6c9227491C0a8156A0106A0204d881BB7E531
    )
    , swaps AS (
        select 
            contract_address,
            evt_tx_hash,
            evt_index,
            evt_block_time,
            evt_block_number,
            'Swap' as evt_name,
            amount0,
            amount1
        from uniswap_v3_ethereum.Pair_evt_Swap
        where contract_address=0xe8c6c9227491C0a8156A0106A0204d881BB7E531
    )
    , events AS (
        select * from mints
        union
        select * from burns
        union
        select * from swaps
    )

select * from events
