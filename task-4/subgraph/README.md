## Aave V3 Subgraph

The subgraph tracks user's net supplied amount where,
`net supplied amount = total supplied - total borrowed`

### Example queries,

- latest position of a user in a market,

```
{
  positions{
    user
    asset{id}
    totalSuppliedAmount
    totalBorrowedAmount
    netSuppliedAmount
    blockNumber
  }
}
```

- hourly position snapshots of user's position in a market,

```
{
  positionHourlies(where: {user:"0x..."}, orderBy: hours, orderDirection: desc){
    user
    asset{id}
    totalSuppliedAmount
    totalBorrowedAmount
    netSuppliedAmount
    blockNumber
  }
}
```

_Note: a snapshot is taken only when there is an update in the position_
