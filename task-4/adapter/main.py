import sys
import asyncio
import logging
from datetime import datetime

import config
import getters

from_hours = 0
to_hours = 0
try:
    from_date = datetime.strptime(config.from_date, "%Y-%m-%d %H:%M:%S")
    to_date = datetime.strptime(config.to_date, "%Y-%m-%d %H:%M:%S")

    from_hours = int(datetime.timestamp(from_date) / (60 * 60))
    to_hours = int(datetime.timestamp(to_date) / (60 * 60))
except:
    logging.error("Wrong date format. Run again.")
    sys.exit(1)

asyncio.run(getters.get_hourly_data(
    config.assets, from_hours, to_hours))
