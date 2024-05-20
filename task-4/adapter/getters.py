import logging
import pandas as pd
from aiohttp import ClientSession

import config
import utils

q = """
query($first: Int!, $blockNumber_gt: Int!, $asset_in: [String!], $hours_gte: Int!, $hours_lt: Int!) {
    data: positionHourlies(first: $first, orderBy: blockNumber, orderDirection: asc, where:{blockNumber_gt: $blockNumber_gt, asset_in: $asset_in, hours_gte: $hours_gte, hours_lt: $hours_lt}){
    blockNumber
    timestamp
    user
    asset{
      id
    }
    totalSuppliedAmount
    totalBorrowedAmount
    netSuppliedAmount
    hours
  }
}
"""


async def get_hourly_data(assets, from_hours, to_hours):
    query = {
        "query": q,
        "variables": {
            "first": 100,
            "blockNumber_gt": 0,
            "asset_in": assets,
            "hours_gte": from_hours,
            "hours_lt": to_hours,
        },
    }

    data = []
    async with ClientSession() as session:
        data = await loop_query(session, query)

    utils.write_to_csv(config.output_csv, pd.DataFrame(data))
    return data


async def loop_query(session, query):
    data = []
    continue_loop = True
    while continue_loop:
        async with session.post(config.deployment_uri, json=query) as response:
            response = await response.json()
            if "data" not in response:
                logging.error(
                    f"no data\n response: {response}\n query: {query}")
                return data

            response_data = response["data"]["data"]
            data.extend(response_data)

            if len(response_data) != query["variables"]["first"]:
                continue_loop = False
            else:
                df = pd.DataFrame(data)
                query["variables"]["blockNumber_gt"] = int(
                    df["blockNumber"].max())
    return data
