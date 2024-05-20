-- https://dune.com/queries/3748327/6304441/

WITH
    pools AS (
        select 
            aToken,
            asset,
            stableDebtToken,
            variableDebtToken
        from aave_v3_ethereum.PoolConfigurator_evt_ReserveInitialized
    )
    , supply_events AS (
        select 
            contract_address,
            evt_tx_hash,
            evt_index,
            evt_block_time,
            evt_block_number,
            'Supply' as evt_name,
            reserve as asset,
            amount,
            onBehalfOf as user
        from aave_v3_ethereum.Pool_evt_Supply
    )
    , withdraw_events AS (
        select 
            contract_address,
            evt_tx_hash,
            evt_index,
            evt_block_time,
            evt_block_number,
            'Withdraw' as evt_name,
            reserve as asset,
            -amount,
            user
        from aave_v3_ethereum.Pool_evt_Withdraw
    )
    , liquidation_events AS (
        select
            contract_address,
            evt_tx_hash,
            evt_index,
            evt_block_time,
            evt_block_number,
            'Liquidation' as evt_name,
            collateralAsset as asset,
            -liquidatedCollateralAmount as amount,
            user
        from aave_v3_ethereum.Pool_evt_LiquidationCall
    )
    , liquidator_events AS (
        select
            contract_address,
            evt_tx_hash,
            evt_index,
            evt_block_time,
            evt_block_number,
            'Liquidator' as evt_name,
            debtAsset as asset,
            IF(receiveAToken, debtToCover, 0) as amount,
            liquidator as user
        from aave_v3_ethereum.Pool_evt_LiquidationCall
    )
    , transfer_outs AS (
        select
            t.contract_address,
            t.evt_tx_hash,
            t.evt_index,
            t.evt_block_time,
            t.evt_block_number,
            'Transfer Out' as evt_name,
            p.asset as asset,
            -IF(t.value > bt.value, t.value, bt.value) as amount,
            t."from" as user
        from aave_v3_ethereum.AToken_evt_Transfer t
        inner join aave_v3_ethereum.AToken_evt_BalanceTransfer bt
            on t.evt_tx_hash = bt.evt_tx_hash
            and t.contract_address = bt.contract_address
            and t."from" = bt."from"
            and t.to = bt.to
        left join pools p
            on t.contract_address = p.aToken
    )
    , transfer_ins AS (
        select
            t.contract_address,
            t.evt_tx_hash,
            t.evt_index,
            t.evt_block_time,
            t.evt_block_number,
            'Transfer In' as evt_name,
            p.asset as asset,
            IF(t.value > bt.value, t.value, bt.value) as amount,
            t.to as user
        from aave_v3_ethereum.AToken_evt_Transfer t
        inner join aave_v3_ethereum.AToken_evt_BalanceTransfer bt
            on t.evt_tx_hash = bt.evt_tx_hash
            and t.contract_address = bt.contract_address
            and t."from" = bt."from"
            and t.to = bt.to
        left join pools p
            on t.contract_address = p.aToken
    )
    , events AS (
        select * from supply_events
        union
        select * from withdraw_events
        union
        select * from liquidation_events
        union
        select * from liquidator_events
        union
        select * from transfer_outs
        union
        select * from transfer_ins
    )
    , events_agg AS (
        select
            *,
            IF(SUM(amount) OVER (PARTITION BY asset, user ORDER BY evt_block_number, evt_index) > 0, 
                SUM(amount) OVER (PARTITION BY asset, user ORDER BY evt_block_number, evt_index),
                0) as liquidity
        from events
    )
    , events_grouped AS (
        select 
            *,
            ROW_NUMBER() OVER(PARTITION by asset, user order by evt_block_time desc, evt_index desc) as row_number
        from events_agg
    )
    
select
    g.user as liquidity_provider,
    g.asset,
    (g.liquidity / pow(10, p.decimals) * p.price) as liquidity_usd
from (select * from events_grouped where row_number = 1) g
left join (select * from prices.usd_latest where blockchain = 'ethereum') p
    on g.asset = p.contract_address
where g.liquidity > 0
