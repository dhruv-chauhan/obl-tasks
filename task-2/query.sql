-- https://dune.com/queries/3748341/6304471/

WITH
    mints AS (
        select
            t.tokenId,
            t.to as owner,
            t.evt_block_number,
            t.evt_index
        from uniswap_v3_ethereum.NonfungibleTokenPositionManager_evt_Transfer t
        left join uniswap_v3_ethereum.NonfungibleTokenPositionManager_evt_IncreaseLiquidity il
            on t.evt_tx_hash = il.evt_tx_hash
            and t.tokenId = il.tokenId
        left join uniswap_v3_ethereum.Pair_evt_Mint m
            on m.evt_tx_hash = il.evt_tx_hash
            and m.amount = il.liquidity
            and m.amount0 = il.amount0
            and m.amount1 = il.amount1
        where "from" = 0x0000000000000000000000000000000000000000
        and m.contract_address = 0xe8c6c9227491C0a8156A0106A0204d881BB7E531
    )
    , transfers AS (
        select
            tokenId,
            to as owner,
            evt_block_number,
            evt_index
        from uniswap_v3_ethereum.NonfungibleTokenPositionManager_evt_Transfer
        where tokenId in (select tokenId from mints)
    )
    , transfers_grouped AS (
        select
            *,
            ROW_NUMBER() OVER(PARTITION by tokenId order by evt_block_number desc, evt_index desc) as row_number
        from transfers
    )
    , liquidity_changes AS (
        select
            tokenId,
            amount0,
            amount1,
            liquidity,
            'IncreaseLiquidity' as evt_name,
            evt_tx_hash,
            evt_block_number,
            evt_index
        from uniswap_v3_ethereum.NonfungibleTokenPositionManager_evt_IncreaseLiquidity
        where tokenId in (select tokenId from mints) 
    
        union all 
        
        select
            tokenId,
            amount0,
            amount1,
            liquidity,
            'DecreaseLiquidity' as evt_name,
            evt_tx_hash,
            evt_block_number,
            evt_index
        from uniswap_v3_ethereum.NonfungibleTokenPositionManager_evt_DecreaseLiquidity
        where tokenId in (select tokenId from mints) 
    )
    , liquidity_changes_grouped AS (
        select
            *,
            ROW_NUMBER() OVER(PARTITION by tokenId order by evt_block_number desc, evt_index desc) as row_number
        from liquidity_changes
    )
    , withdrawals AS (
        select
            tokenId,
            amount0,
            SUM(amount0) OVER (order by evt_block_number, evt_index) as cum_amount0,
            amount1,
            SUM(amount1) OVER (order by evt_block_number, evt_index) as cum_amount1,
            'Collect' as evt_name,
            evt_tx_hash,
            evt_block_number,
            evt_index
        from uniswap_v3_ethereum.NonfungibleTokenPositionManager_evt_Collect
        where tokenId in (select tokenId from mints) 
    )
    , withdrawals_grouped AS (
        select
            *,
            ROW_NUMBER() OVER(PARTITION by tokenId order by evt_block_number desc, evt_index desc) as row_number
        from withdrawals
    )
    , liquidity AS (
        select 
            lg.tokenId,
            IF(w.cum_amount0 is not null, IF(lg.amount0 > w.cum_amount0, lg.amount0 - w.cum_amount0, 0), lg.amount0) as amount0,
            IF(w.cum_amount1 is not null, IF(lg.amount1 > w.cum_amount1, lg.amount1 - w.cum_amount1, 0), lg.amount1) as amount1
        from (select * from liquidity_changes_grouped where row_number = 1) lg
        left join (select * from withdrawals_grouped where row_number = 1) w
            on lg.tokenId = w.tokenId
    )
    , liquidity_x_owners AS (
        select
            l.tokenId,
            t.owner,
            l.amount0,
            l.amount1
        from liquidity l
        left join transfers_grouped t
            on l.tokenId = t.tokenId
    )
    
select 
    owner as liquidity_provider,
    0xe8c6c9227491C0a8156A0106A0204d881BB7E531 as pool_contract_address,
    (amount0 / pow(10, p0.decimals) * p0.price) + (amount1 / pow(10, p1.decimals) * p1.price) as liquidity_usd
from liquidity_x_owners
left join (select * from prices.usd_latest where blockchain = 'ethereum') p0
    on p0.contract_address = 0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2 -- MKR
left join (select * from prices.usd_latest where blockchain = 'ethereum') p1
    on p1.contract_address = 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2 -- WETH
where amount0 != 0 
and amount1 != 0 
