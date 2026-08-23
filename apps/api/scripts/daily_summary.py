import csv
import gzip
import io
import os
import sys
import time
from collections import Counter
from datetime import datetime, timedelta, timezone

import jwt
import requests

ASC_SALES = "https://api.appstoreconnect.apple.com/v1/salesReports"
NOTIFI_SEND = "https://notifi.it/send"
D1_QUERY = (
    "https://api.cloudflare.com/client/v4/accounts/{account}/d1/database/{database}/query"
)
FIRST_INSTALL = {"1", "1F"}
WEEK = 604800
SESSION = requests.Session()
SESSION.headers["User-Agent"] = "notifi-daily-summary"


def app_store_connect_token():
    key = os.environ.get("ASC_PRIVATE_KEY")
    if key is None:
        key = open(os.environ["ASC_KEY_PATH"]).read()
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
        key,
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"]},
    )


def first_installs_on(token, day):
    res = SESSION.get(
        ASC_SALES,
        headers={"Authorization": f"Bearer {token}", "Accept": "application/a-gzip"},
        params={
            "filter[frequency]": "DAILY",
            "filter[reportType]": "SALES",
            "filter[reportSubType]": "SUMMARY",
            "filter[vendorNumber]": os.environ["ASC_VENDOR_NUMBER"],
            "filter[reportDate]": day,
        },
        timeout=30,
    )
    if res.status_code == 404:
        return 0, Counter()
    res.raise_for_status()

    tsv = gzip.decompress(res.content).decode()
    total, countries = 0, Counter()
    for row in csv.DictReader(io.StringIO(tsv), delimiter="\t"):
        if row["Product Type Identifier"] not in FIRST_INSTALL:
            continue
        units = int(row["Units"])
        total += units
        countries[row["Country Code"]] += units
    return total, countries


def query_production_d1(sql):
    res = SESSION.post(
        D1_QUERY.format(
            account=os.environ["CLOUDFLARE_ACCOUNT_ID"],
            database=os.environ["D1_DATABASE_ID"],
        ),
        headers={"Authorization": f"Bearer {os.environ['CLOUDFLARE_API_TOKEN']}"},
        json={"sql": sql},
        timeout=30,
    )
    res.raise_for_status()
    body = res.json()
    if not body["success"]:
        raise SystemExit(f"D1 query failed: {body['errors']}")
    return body["result"][0]["results"][0]


def week_on_week(now, before, percent_floor=10):
    if before >= percent_floor:
        return f"{'+' if now >= before else ''}{round((now - before) / before * 100)}%"
    return f"{'+' if now >= before else ''}{now - before}"


def compose_notification():
    token = app_store_connect_token()
    today = datetime.now(timezone.utc)
    reports = [
        first_installs_on(token, (today - timedelta(days=n)).strftime("%Y-%m-%d"))
        for n in range(1, 15)
    ]

    yesterday, countries = reports[0]
    this_week = sum(n for n, _ in reports[:7])
    prior_week = sum(n for n, _ in reports[7:])

    stats = query_production_d1(
        "SELECT (SELECT COUNT(*) FROM devices) AS devices,"
        " (SELECT COUNT(*) FROM devices WHERE created_at >= unixepoch()-604800) AS devices_wk,"
        " (SELECT COUNT(*) FROM app_reviews) AS reviews"
    )
    sends = query_production_d1(
        "SELECT SUM(CASE WHEN created_at >= unixepoch()-604800 THEN 1 ELSE 0 END) AS wk,"
        " SUM(CASE WHEN created_at >= unixepoch()-1209600 AND created_at < unixepoch()-604800 THEN 1 ELSE 0 END) AS prior,"
        " MIN(created_at) AS oldest FROM messages"
    )

    comparable = sends["oldest"] is not None and sends["oldest"] <= int(time.time()) - 2 * WEEK
    plural = "" if yesterday == 1 else "s"

    lines = [
        f"**{yesterday}** download{plural} yesterday · **{this_week}** this week "
        f"({week_on_week(this_week, prior_week)} vs prior 7d).",
        "",
        f"- Sends **{sends['wk']}** this week ({week_on_week(sends['wk'], sends['prior'])} vs prior 7d)"
        if comparable
        else f"- Sends **{sends['wk']}** this week · _no prior week to compare yet_",
        f"- Devices **{stats['devices']}** · +{stats['devices_wk']} this week",
        f"- Reviews **{stats['reviews']}**",
    ]
    if countries:
        lines.append("- From " + " · ".join(f"{c} {n}" for c, n in countries.most_common(4)))

    return f"notifi · {yesterday} download{plural} yesterday", "\n".join(lines)


def send_daily_summary():
    title, body = compose_notification()
    if "--dry-run" in sys.argv:
        print(f"--- title ---\n{title}\n--- body ---\n{body}")
        return
    res = SESSION.post(
        NOTIFI_SEND,
        data={"key": os.environ["NOTIFI_SEND_KEY"], "title": title, "message": body},
        timeout=30,
    )
    print(f"send: {res.status_code}")
    if not res.ok:
        raise SystemExit(res.text[:200])


if __name__ == "__main__":
    send_daily_summary()
