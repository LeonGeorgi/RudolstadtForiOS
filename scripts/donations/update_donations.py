#!/usr/bin/env python3
"""Publish only calendar-year/customer-currency totals from Apple sales reports."""

import argparse
import calendar
import csv
import gzip
import io
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from decimal import Decimal, InvalidOperation, localcontext
from pathlib import Path
from zoneinfo import ZoneInfo


APP_ID = "1629927812"
FIRST_YEAR = 2022
DONATION_IDS = frozenset({
    "donation200", "donation500", "donation1000", "donation2000", "donation5000",
})
API = "https://api.appstoreconnect.apple.com"
REQUIRED_COLUMNS = {
    "SKU", "Parent Identifier", "Units", "Customer Price", "Customer Currency",
    "Begin Date", "End Date",
}


class ReportError(Exception):
    """A safe diagnostic which contains no report contents or credentials."""


@dataclass(frozen=True)
class Period:
    frequency: str
    start: date
    end: date

    @property
    def report_date(self):
        formats = {"DAILY": "%Y-%m-%d", "MONTHLY": "%Y-%m", "YEARLY": "%Y"}
        return self.start.strftime(formats[self.frequency])


def report_periods(today, first_year=FIRST_YEAR):
    """Disjoint reports: annual history, closed months, then recent days.

    Keep two days of reporting lag. Monthly/yearly reports become usable only
    after Apple's publication window; until then use the smaller periods.
    """
    through = today - timedelta(days=2)
    if not FIRST_YEAR <= first_year <= today.year:
        raise ReportError(f"First year must be between {FIRST_YEAR} and {today.year}.")
    for year in range(first_year, through.year + 1):
        year_end = date(year, 12, 31)
        if year_end <= through and today >= date(year + 1, 1, 7):
            yield Period("YEARLY", date(year, 1, 1), year_end)
            continue
        for month in range(1, 13):
            start = date(year, month, 1)
            if start > through:
                break
            end = date(year, month, calendar.monthrange(year, month)[1])
            if end <= through and today >= end + timedelta(days=6):
                yield Period("MONTHLY", start, end)
                continue
            for day in range(1, min(end, through).day + 1):
                current = date(year, month, day)
                yield Period("DAILY", current, current)


def decimal_value(value):
    try:
        number = Decimal(value)
    except (InvalidOperation, TypeError):
        raise ReportError("Donation row has an invalid numeric value.") from None
    if not number.is_finite():
        raise ReportError("Donation row has a non-finite numeric value.")
    return number


def aggregate_report(payload, period, app_sku):
    """Read in memory; never return or log product, country or customer details."""
    try:
        text = gzip.decompress(payload).decode("utf-8-sig")
    except (OSError, EOFError, UnicodeError):
        raise ReportError("Apple returned an invalid compressed sales report.") from None
    reader = csv.DictReader(io.StringIO(text), delimiter="\t")
    if not REQUIRED_COLUMNS.issubset(reader.fieldnames or []):
        raise ReportError("Sales report is missing required columns.")
    totals = defaultdict(Decimal)
    for row in reader:
        try:
            begin = datetime.strptime(row["Begin Date"], "%m/%d/%Y").date()
            end = datetime.strptime(row["End Date"], "%m/%d/%Y").date()
        except (ValueError, TypeError):
            raise ReportError("Sales report has an invalid reporting period.") from None
        if begin != period.start or end != period.end:
            raise ReportError("Sales report does not match the requested reporting period.")
        if row["SKU"] not in DONATION_IDS or row["Parent Identifier"] != app_sku:
            continue
        units = decimal_value(row["Units"])
        price = decimal_value(row["Customer Price"])
        if units == 0 and price != 0:
            raise ReportError("A zero-unit adjustment needs manual review; totals were not published.")
        if price == 0:
            continue  # Free redemptions contributed no funds, even if currency is blank.
        currency = row["Customer Currency"]
        if not re.fullmatch(r"[A-Z]{3}", currency or ""):
            raise ReportError("Donation row has an invalid customer currency.")
        with localcontext() as context:
            context.prec = 50
            amount = abs(units) * abs(price)
            # Apple marks refunds with negative units AND negative customer price.
            if units < 0 or price < 0:
                amount = -amount
            totals[currency] += amount
    return dict(totals)


def collect_totals(client, periods, app_sku):
    totals = {}
    for period in periods:
        year = str(period.start.year)
        yearly = totals.setdefault(year, defaultdict(Decimal))
        payload = client.sales_report(period)
        if payload is None:
            continue  # Only Apple's explicit "no sales" response is an empty period.
        for currency, amount in aggregate_report(payload, period, app_sku).items():
            with localcontext() as context:
                context.prec = 50
                yearly[currency] += amount
    return {
        year: {currency: format_amount(amount) for currency, amount in sorted(yearly.items())}
        for year, yearly in sorted(totals.items())
    }


def format_amount(amount):
    if amount == 0:
        return "0.00"
    whole, _, fraction = format(amount, "f").partition(".")
    return whole + "." + fraction.rstrip("0").ljust(2, "0")


class AppleClient:
    def __init__(self, key_id, issuer_id, private_key, vendor_number):
        self.key_id = key_id
        self.issuer_id = issuer_id
        self.private_key = private_key
        self.vendor_number = vendor_number

    def token(self):
        import jwt

        now = int(time.time())
        return jwt.encode(
            {"iss": self.issuer_id, "iat": now, "exp": now + 600,
             "aud": "appstoreconnect-v1"},
            self.private_key, algorithm="ES256",
            headers={"kid": self.key_id, "typ": "JWT"},
        )

    def request(self, path, parameters):
        url = f"{API}{path}?{urllib.parse.urlencode(parameters)}"
        for attempt in range(3):
            request = urllib.request.Request(url, headers={
                "Authorization": f"Bearer {self.token()}",
                "Accept": "application/a-gzip" if path == "/v1/salesReports" else "application/json",
            })
            try:
                with urllib.request.urlopen(request, timeout=60) as response:
                    return response.read()
            except urllib.error.HTTPError as error:
                body = error.read()
                if error.code == 404 and path == "/v1/salesReports":
                    try:
                        errors = json.loads(body).get("errors", [])
                        no_sales = any("there were no sales" in item.get("detail", "").lower()
                                       for item in errors)
                    except (ValueError, AttributeError, TypeError):
                        no_sales = False
                    if no_sales:
                        return None
                if error.code not in {429, 500, 502, 503, 504} or attempt == 2:
                    raise ReportError(f"Apple API returned HTTP {error.code}; publication stopped.") from None
            except (urllib.error.URLError, TimeoutError):
                if attempt == 2:
                    raise ReportError("Apple API could not be reached; publication stopped.") from None
            time.sleep(2 ** attempt)

    def app_sku(self):
        payload = self.request(f"/v1/apps/{APP_ID}", {"fields[apps]": "sku"})
        try:
            sku = json.loads(payload)["data"]["attributes"]["sku"]
            if not isinstance(sku, str) or not sku:
                raise ValueError()
            return sku
        except (ValueError, KeyError, TypeError):
            raise ReportError("Apple did not return the app's SKU; publication stopped.") from None

    def sales_report(self, period):
        return self.request("/v1/salesReports", {
            "filter[frequency]": period.frequency,
            "filter[reportDate]": period.report_date,
            "filter[reportType]": "SALES",
            "filter[reportSubType]": "SUMMARY",
            "filter[version]": "1_0",
            "filter[vendorNumber]": self.vendor_number,
        })


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--first-year", type=int, default=FIRST_YEAR)
    args = parser.parse_args()
    names = ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY", "ASC_VENDOR_NUMBER")
    missing = [name for name in names if not os.environ.get(name, "").strip()]
    if missing:
        raise ReportError("Missing GitHub secrets: " + ", ".join(missing))
    client = AppleClient(*(os.environ[name].strip() for name in names))
    periods = report_periods(datetime.now(ZoneInfo("America/Los_Angeles")).date(), args.first_year)
    totals = collect_totals(client, periods, client.app_sku())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    # Write only after every requested report was retrieved and validated.
    args.output.write_text(json.dumps(totals, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("Yearly donation totals prepared. No source reports were written to disk.")


if __name__ == "__main__":
    try:
        main()
    except ReportError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
