import csv
import gzip
import io
import json
import os
import tempfile
import unittest
import urllib.error
from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path
from unittest.mock import patch

from update_donations import (
    AppleClient, Period, ReportError, aggregate_report, collect_totals, main, report_periods,
)


APP_SKU = "test-app-sku"
DAY = Period("DAILY", date(2026, 6, 1), date(2026, 6, 1))


def report(rows, period=DAY):
    columns = ["SKU", "Parent Identifier", "Units", "Customer Price", "Customer Currency",
               "Begin Date", "End Date", "Developer Proceeds", "Title", "Country Code"]
    output = io.StringIO()
    writer = csv.DictWriter(output, fieldnames=columns, delimiter="\t")
    writer.writeheader()
    for changes in rows:
        row = {
            "SKU": "donation1000", "Parent Identifier": APP_SKU,
            "Units": "1.00", "Customer Price": "10.00", "Customer Currency": "EUR",
            "Begin Date": period.start.strftime("%m/%d/%Y"),
            "End Date": period.end.strftime("%m/%d/%Y"),
            "Developer Proceeds": "6.99", "Title": "PRIVATE REPORT TITLE",
            "Country Code": "DE",
        }
        row.update(changes)
        writer.writerow(row)
    return gzip.compress(output.getvalue().encode("utf-8"))


class AggregationTests(unittest.TestCase):
    def test_sums_customer_prices_per_currency_and_filters_app_and_products(self):
        payload = report([
            {"Units": "3"},
            {"SKU": "donation500", "Customer Price": "4.99", "Customer Currency": "USD"},
            {"Parent Identifier": "another-app", "Units": "500"},
            {"SKU": "a-subscription", "Units": "500"},
        ])
        self.assertEqual(aggregate_report(payload, DAY, APP_SKU),
                         {"EUR": Decimal("30.00"), "USD": Decimal("4.99")})

    def test_refunds_with_both_negative_fields_are_subtracted_once(self):
        payload = report([{"Units": "3"}, {"Units": "-2", "Customer Price": "-10.00"}])
        self.assertEqual(aggregate_report(payload, DAY, APP_SKU), {"EUR": Decimal("10.00")})

    def test_refunds_with_one_negative_field_also_reduce_the_total(self):
        for changes in ({"Units": "-1"}, {"Customer Price": "-10.00"}):
            with self.subTest(changes=changes):
                self.assertEqual(aggregate_report(report([changes]), DAY, APP_SKU),
                                 {"EUR": Decimal("-10.00")})

    def test_decimal_precision_and_three_decimal_currency_are_preserved(self):
        payload = report([{"Units": "3", "Customer Price": "0.101", "Customer Currency": "KWD"}])
        self.assertEqual(aggregate_report(payload, DAY, APP_SKU), {"KWD": Decimal("0.303")})

    def test_zero_unit_adjustment_is_not_silently_discarded(self):
        with self.assertRaisesRegex(ReportError, "zero-unit adjustment"):
            aggregate_report(report([{"Units": "0", "Customer Price": "-1.50"}]), DAY, APP_SKU)

    def test_free_redemptions_do_not_add_funds_or_require_a_currency(self):
        self.assertEqual(aggregate_report(report([{"Customer Price": "0", "Customer Currency": ""}]),
                                          DAY, APP_SKU), {})

    def test_invalid_money_or_currency_stops_publication_without_leaking_rows(self):
        for changes in ({"Units": "NaN"}, {"Customer Price": "Infinity"},
                        {"Customer Price": ""}, {"Customer Currency": "USD extra private data"}):
            with self.subTest(changes=changes), self.assertRaises(ReportError) as failure:
                aggregate_report(report([changes]), DAY, APP_SKU)
            self.assertNotIn("PRIVATE REPORT TITLE", str(failure.exception))

    def test_malformed_or_unexpected_reports_are_rejected(self):
        for payload in (b"not gzip", gzip.compress(b"unexpected\tcolumns\n")):
            with self.subTest(payload=payload), self.assertRaises(ReportError):
                aggregate_report(payload, DAY, APP_SKU)
        with self.assertRaisesRegex(ReportError, "requested reporting period"):
            aggregate_report(report([{"End Date": "06/02/2026"}]), DAY, APP_SKU)

    def test_public_output_contains_only_year_currency_and_decimal_strings(self):
        other_year = Period("YEARLY", date(2025, 1, 1), date(2025, 12, 31))

        class Client:
            def sales_report(self, period):
                return report([{}], period)

        totals = collect_totals(Client(), [other_year, DAY], APP_SKU)
        self.assertEqual(totals, {"2025": {"EUR": "10.00"}, "2026": {"EUR": "10.00"}})
        output = json.dumps(totals)
        for private in ("PRIVATE", "SKU", APP_SKU, "Country", "Units", "donation1000"):
            self.assertNotIn(private, output)

    def test_explicit_no_sales_produces_empty_year_not_a_fabricated_amount(self):
        class Client:
            def sales_report(self, period):
                return None

        self.assertEqual(collect_totals(Client(), [DAY], APP_SKU), {"2026": {}})

    def test_failed_run_does_not_replace_existing_output(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "donations.json"
            output.write_text('previous verified data\n')
            secrets = {name: "test-only" for name in
                       ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY", "ASC_VENDOR_NUMBER")}
            with patch.dict(os.environ, secrets), \
                 patch("sys.argv", ["update_donations.py", "--output", str(output)]), \
                 patch("update_donations.AppleClient") as client:
                client.return_value.app_sku.return_value = APP_SKU
                client.return_value.sales_report.side_effect = ReportError("Missing report")
                with self.assertRaises(ReportError):
                    main()
            self.assertEqual(output.read_text(), 'previous verified data\n')


class ReportingPeriodTests(unittest.TestCase):
    def assert_complete_disjoint_coverage(self, today):
        periods = list(report_periods(today))
        self.assertEqual(periods[0].start, date(2022, 1, 1))
        self.assertEqual(periods[-1].end, today - timedelta(days=2))
        for previous, following in zip(periods, periods[1:]):
            self.assertEqual(previous.end + timedelta(days=1), following.start)
        self.assertTrue(all(period.start.year == period.end.year for period in periods))
        return periods

    def test_every_day_around_year_and_month_rollovers_has_no_gaps_or_overlap(self):
        for year in (2024, 2025, 2026):
            for month in range(1, 13):
                for day in (1, 2, 5, 6, 7, 15, 28):
                    today = date(year, month, day)
                    with self.subTest(today=today):
                        self.assert_complete_disjoint_coverage(today)

    def test_recent_month_remains_daily_until_monthly_report_is_ready(self):
        early = self.assert_complete_disjoint_coverage(date(2026, 2, 4))
        self.assertFalse(any(p.frequency == "MONTHLY" and p.start.month == 1
                             and p.start.year == 2026 for p in early))
        ready = self.assert_complete_disjoint_coverage(date(2026, 2, 7))
        self.assertIn(Period("MONTHLY", date(2026, 1, 1), date(2026, 1, 31)), ready)

    def test_yearly_history_replaces_smaller_reports_after_publication_window(self):
        periods = self.assert_complete_disjoint_coverage(date(2026, 1, 7))
        previous_year = [p for p in periods if p.start.year == 2025]
        self.assertEqual(previous_year, [Period("YEARLY", date(2025, 1, 1), date(2025, 12, 31))])

    def test_api_date_formats(self):
        self.assertEqual(DAY.report_date, "2026-06-01")
        self.assertEqual(Period("MONTHLY", date(2026, 6, 1), date(2026, 6, 30)).report_date,
                         "2026-06")
        self.assertEqual(Period("YEARLY", date(2025, 1, 1), date(2025, 12, 31)).report_date,
                         "2025")


class AppleResponseTests(unittest.TestCase):
    def setUp(self):
        self.client = AppleClient("key", "issuer", "private", "vendor")
        self.token_patch = patch.object(self.client, "token", return_value="test-token")
        self.token_patch.start()
        self.addCleanup(self.token_patch.stop)

    def response_error(self, status, detail):
        return urllib.error.HTTPError("https://private-url", status, "private detail", {},
                                      io.BytesIO(json.dumps({"errors": [{"detail": detail}]}).encode()))

    def test_only_explicit_no_sales_is_treated_as_zero(self):
        error = self.response_error(404, "There were no sales for the date specified.")
        with patch("urllib.request.urlopen", side_effect=error):
            self.assertIsNone(self.client.sales_report(DAY))

    def test_missing_or_unauthorized_reports_stop_without_logging_private_response(self):
        for status in (401, 403, 404):
            with self.subTest(status=status):
                error = self.response_error(status, "PRIVATE REPORT CONTENTS")
                with patch("urllib.request.urlopen", side_effect=error), \
                     self.assertRaisesRegex(ReportError, f"HTTP {status}") as failure:
                    self.client.sales_report(DAY)
                self.assertNotIn("PRIVATE", str(failure.exception))
                self.assertNotIn("private-url", str(failure.exception))

    def test_transient_failures_are_retried_but_never_published_as_zero(self):
        errors = [self.response_error(503, "private") for _ in range(3)]
        with patch("urllib.request.urlopen", side_effect=errors) as request, \
             patch("time.sleep"), self.assertRaisesRegex(ReportError, "HTTP 503"):
            self.client.sales_report(DAY)
        self.assertEqual(request.call_count, 3)


if __name__ == "__main__":
    unittest.main()
