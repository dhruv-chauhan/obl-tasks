import { Address, BigInt, ethereum } from "@graphprotocol/graph-ts";

import { Position, PositionHourly } from "../generated/schema";

export const ZERO_ADDRESS = Address.fromString(
  "0x0000000000000000000000000000000000000000"
);

export namespace InterestRateMode {
  export const UNDEFINED = "undefined";
  export const STABLE = "stable";
  export const VARIABLE = "variable";
}

export function getOrCreatePosition(user: string, asset: string): Position {
  const id = user.concat("-").concat(asset);
  let position = Position.load(id);
  if (!position) {
    position = new Position(id);
    position.user = user;
    position.asset = asset;
    position.interestRateMode = InterestRateMode.UNDEFINED;
    position.totalSuppliedAmount = BigInt.fromI32(0);
    position.totalBorrowedAmount = BigInt.fromI32(0);
    position.netSuppliedAmount = BigInt.fromI32(0);
    position.blockNumber = BigInt.fromI32(0);
    position.timestamp = BigInt.fromI32(0);
    position.save();
  }
  return position;
}

export function takeSnapshot(position: Position, event: ethereum.Event): void {
  const hours = event.block.timestamp.toI32() / (60 * 60);
  const id = position.id.concat("-").concat(hours.toString());
  let positionHourly = PositionHourly.load(id);
  if (!positionHourly) {
    positionHourly = new PositionHourly(id);
    positionHourly.user = position.user;
    positionHourly.asset = position.asset;
    positionHourly.hours = hours;
  }
  positionHourly.totalSuppliedAmount = position.totalSuppliedAmount;
  positionHourly.totalBorrowedAmount = position.totalBorrowedAmount;
  positionHourly.netSuppliedAmount = position.netSuppliedAmount;
  positionHourly.blockNumber = event.block.number;
  positionHourly.timestamp = event.block.timestamp;
  positionHourly.save();
}
