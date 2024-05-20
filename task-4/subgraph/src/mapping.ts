import { BigInt, dataSource, log } from "@graphprotocol/graph-ts";

import {
  getOrCreatePosition,
  InterestRateMode,
  takeSnapshot,
  ZERO_ADDRESS,
} from "./utils";

import { Asset, AToken } from "../generated/schema";
import { ReserveInitialized } from "../generated/PoolConfigurator/PoolConfigurator";
import {
  ReserveDataUpdated,
  Supply,
  Withdraw,
  Borrow,
  Repay,
  LiquidationCall,
} from "../generated/Pool/Pool";
import { AToken as ATokenTemplate } from "../generated/templates";
import { Transfer } from "../generated/templates/AToken/AToken";

export function handleReserveInitialized(event: ReserveInitialized): void {
  const _aToken = event.params.aToken;
  const _asset = event.params.asset;
  const stableDebtToken = event.params.stableDebtToken;
  const variableDebtToken = event.params.variableDebtToken;

  const aToken = new AToken(_aToken.toHexString());
  aToken.asset = _asset.toHexString();
  aToken.stableDebtToken = stableDebtToken.toHexString();
  aToken.variableDebtToken = variableDebtToken.toHexString();
  aToken.liquidityIndex = BigInt.fromI32(10).pow(27);
  aToken.save();

  const asset = new Asset(_asset.toHexString());
  asset.aToken = aToken.id;
  asset.save();

  ATokenTemplate.create(_aToken);
}

export function handleReserveDataUpdated(event: ReserveDataUpdated): void {
  const reserve = event.params.reserve;
  const liquidityIndex = event.params.liquidityIndex;

  const asset = Asset.load(reserve.toHexString());
  if (!asset) {
    log.critical("Asset not initialized: {}", [reserve.toHexString()]);
    return;
  }

  let aToken = AToken.load(asset.aToken);
  if (!aToken) {
    log.critical("AToken not initialized: {}", [asset.aToken]);
    return;
  }
  aToken.liquidityIndex = liquidityIndex;
  aToken.save();
}

export function handleSupply(event: Supply): void {
  const reserve = event.params.reserve;
  const user = event.params.onBehalfOf;
  const amount = event.params.amount;

  const position = getOrCreatePosition(
    user.toHexString(),
    reserve.toHexString()
  );
  position.totalSuppliedAmount = position.totalSuppliedAmount.plus(amount);
  position.netSuppliedAmount = position.totalSuppliedAmount.minus(
    position.totalBorrowedAmount
  );
  position.blockNumber = event.block.number;
  position.timestamp = event.block.timestamp;
  position.save();

  takeSnapshot(position, event);
}

export function handleWithdraw(event: Withdraw): void {
  const reserve = event.params.reserve;
  const user = event.params.user;
  const amount = event.params.amount;

  const position = getOrCreatePosition(
    user.toHexString(),
    reserve.toHexString()
  );
  position.totalSuppliedAmount = position.totalSuppliedAmount.minus(amount);
  position.netSuppliedAmount = position.totalSuppliedAmount.minus(
    position.totalBorrowedAmount
  );
  position.blockNumber = event.block.number;
  position.timestamp = event.block.timestamp;
  position.save();

  takeSnapshot(position, event);
}

export function handleBorrow(event: Borrow): void {
  const reserve = event.params.reserve;
  const user = event.params.onBehalfOf;
  const amount = event.params.amount;
  const interestRateMode = event.params.interestRateMode;

  const position = getOrCreatePosition(
    user.toHexString(),
    reserve.toHexString()
  );
  position.interestRateMode =
    interestRateMode == (1 as i32)
      ? InterestRateMode.STABLE
      : InterestRateMode.VARIABLE;
  position.totalBorrowedAmount = position.totalBorrowedAmount.plus(amount);
  position.netSuppliedAmount = position.totalSuppliedAmount.minus(
    position.totalBorrowedAmount
  );
  position.blockNumber = event.block.number;
  position.timestamp = event.block.timestamp;
  position.save();

  takeSnapshot(position, event);
}

export function handleRepay(event: Repay): void {
  const reserve = event.params.reserve;
  const user = event.params.repayer;
  const amount = event.params.amount;

  const position = getOrCreatePosition(
    user.toHexString(),
    reserve.toHexString()
  );
  position.totalBorrowedAmount = position.totalBorrowedAmount.minus(amount);
  position.netSuppliedAmount = position.totalSuppliedAmount.minus(
    position.totalBorrowedAmount
  );
  position.blockNumber = event.block.number;
  position.timestamp = event.block.timestamp;
  position.save();

  takeSnapshot(position, event);
}

export function handleLiquidationCall(event: LiquidationCall): void {
  const collateralAsset = event.params.collateralAsset;
  const liquidatee = event.params.user;
  const collateralAmount = event.params.liquidatedCollateralAmount;
  const debtAsset = event.params.debtAsset;
  const liquidator = event.params.liquidator;
  const repaidAmount = event.params.debtToCover;

  const positionLiquidateeSupplied = getOrCreatePosition(
    liquidatee.toHexString(),
    collateralAsset.toHexString()
  );
  positionLiquidateeSupplied.totalSuppliedAmount =
    positionLiquidateeSupplied.totalSuppliedAmount.minus(collateralAmount);
  positionLiquidateeSupplied.netSuppliedAmount =
    positionLiquidateeSupplied.totalSuppliedAmount.minus(
      positionLiquidateeSupplied.totalBorrowedAmount
    );
  positionLiquidateeSupplied.blockNumber = event.block.number;
  positionLiquidateeSupplied.timestamp = event.block.timestamp;
  positionLiquidateeSupplied.save();

  takeSnapshot(positionLiquidateeSupplied, event);

  const positionLiquidateeBorrowed = getOrCreatePosition(
    liquidatee.toHexString(),
    debtAsset.toHexString()
  );
  positionLiquidateeBorrowed.totalBorrowedAmount =
    positionLiquidateeBorrowed.totalBorrowedAmount.minus(repaidAmount);
  positionLiquidateeBorrowed.netSuppliedAmount =
    positionLiquidateeBorrowed.totalSuppliedAmount.minus(
      positionLiquidateeBorrowed.totalBorrowedAmount
    );
  positionLiquidateeBorrowed.blockNumber = event.block.number;
  positionLiquidateeBorrowed.timestamp = event.block.timestamp;
  positionLiquidateeBorrowed.save();

  takeSnapshot(positionLiquidateeBorrowed, event);

  if (event.params.receiveAToken) {
    const positionLiquidator = getOrCreatePosition(
      liquidator.toHexString(),
      debtAsset.toHexString()
    );
    positionLiquidator.totalSuppliedAmount =
      positionLiquidator.totalSuppliedAmount.plus(repaidAmount);
    positionLiquidator.netSuppliedAmount =
      positionLiquidator.totalSuppliedAmount.minus(
        positionLiquidator.totalBorrowedAmount
      );
    positionLiquidator.blockNumber = event.block.number;
    positionLiquidator.timestamp = event.block.timestamp;
    positionLiquidator.save();

    takeSnapshot(positionLiquidator, event);
  }
}

export function handleTransfer(event: Transfer): void {
  const _aToken = dataSource.address();
  const from = event.params.from;
  const to = event.params.to;

  if (
    from == ZERO_ADDRESS ||
    to == ZERO_ADDRESS ||
    from == event.address ||
    to == event.address
  ) {
    // already counted in other events
    return;
  }

  const aToken = AToken.load(_aToken.toHexString());
  if (!aToken) {
    log.critical("AToken not initialized: {}", [_aToken.toHexString()]);
    return;
  }
  const asset = aToken.asset;
  const amount = event.params.value.times(
    aToken.liquidityIndex.div(BigInt.fromI32(10).pow(27))
  );

  const positionFrom = getOrCreatePosition(from.toHexString(), asset);
  positionFrom.totalSuppliedAmount =
    positionFrom.totalSuppliedAmount.minus(amount);
  positionFrom.netSuppliedAmount = positionFrom.totalSuppliedAmount.minus(
    positionFrom.totalBorrowedAmount
  );
  positionFrom.blockNumber = event.block.number;
  positionFrom.timestamp = event.block.timestamp;
  positionFrom.save();

  const positionTo = getOrCreatePosition(to.toHexString(), asset);
  positionTo.totalSuppliedAmount = positionTo.totalSuppliedAmount.plus(amount);
  positionTo.netSuppliedAmount = positionTo.totalSuppliedAmount.minus(
    positionTo.totalBorrowedAmount
  );
  positionTo.blockNumber = event.block.number;
  positionTo.timestamp = event.block.timestamp;
  positionTo.save();

  takeSnapshot(positionFrom, event);
  takeSnapshot(positionTo, event);
}
