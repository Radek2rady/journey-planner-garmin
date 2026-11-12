"""Vercel function serving GET /api/departures; see docs/DEPLOY.md."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from transit_proxy import Handler  # noqa: E402 - needs the path set above


class handler(Handler):  # noqa: N801 - name required by the Vercel Python runtime
    route = "/departures"
