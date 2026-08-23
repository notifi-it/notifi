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
CF_GRAPHQL = "https://api.cloudflare.com/client/v4/graphql"
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


def senders(count):
    return f"{count} device" + ("" if count == 1 else "s")


def site_traffic():
    query = (
        '{ viewer { zones(filter: {zoneTag: "%s"})'
        " { httpRequests1dGroups(limit: 15, filter: {date_gt: \"%s\"}, orderBy: [date_ASC])"
        " { dimensions { date } sum { pageViews } uniq { uniques } } } } }"
    ) % (
        os.environ["CF_ZONE_ID"],
        (datetime.now(timezone.utc) - timedelta(days=15)).strftime("%Y-%m-%d"),
    )
    res = SESSION.post(
        CF_GRAPHQL,
        headers={"Authorization": f"Bearer {os.environ['CLOUDFLARE_API_TOKEN']}"},
        json={"query": query},
        timeout=30,
    )
    res.raise_for_status()
    body = res.json()
    if body.get("errors"):
        raise SystemExit(f"zone analytics failed: {body['errors'][0]['message']}")
    days = {
        g["dimensions"]["date"]: (g["uniq"]["uniques"], g["sum"]["pageViews"])
        for g in body["data"]["viewer"]["zones"][0]["httpRequests1dGroups"]
    }

    def window(start, end):
        u = v = 0
        for n in range(start, end):
            day = (datetime.now(timezone.utc) - timedelta(days=n)).strftime("%Y-%m-%d")
            du, dv = days.get(day, (0, 0))
            u += du
            v += dv
        return u, v

    return window(1, 2), window(1, 8), window(8, 15)


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

    downloads_yesterday, countries = reports[0]
    downloads_week = sum(n for n, _ in reports[:7])
    downloads_prior = sum(n for n, _ in reports[7:])

    day = query_production_d1(
        "SELECT COUNT(*) AS sends, COUNT(DISTINCT device_id) AS senders"
        " FROM messages WHERE created_at >= unixepoch()-86400"
    )
    week = query_production_d1(
        "SELECT COUNT(*) AS sends, COUNT(DISTINCT device_id) AS senders"
        " FROM messages WHERE created_at >= unixepoch()-604800"
    )
    prior = query_production_d1(
        "SELECT COUNT(*) AS sends FROM messages"
        " WHERE created_at >= unixepoch()-1209600 AND created_at < unixepoch()-604800"
    )
    history = query_production_d1("SELECT MIN(created_at) AS oldest FROM messages")
    devices = query_production_d1(
        "SELECT COUNT(*) AS total,"
        " SUM(CASE WHEN created_at >= unixepoch()-86400 THEN 1 ELSE 0 END) AS day,"
        " SUM(CASE WHEN created_at >= unixepoch()-604800 THEN 1 ELSE 0 END) AS week"
        " FROM devices"
    )
    reviews = query_production_d1(
        "SELECT COUNT(*) AS total,"
        " SUM(CASE WHEN substr(updated_at,1,10) >= date('now','-7 days') THEN 1 ELSE 0 END) AS week"
        " FROM app_reviews"
    )
    active_keys = query_production_d1(
        "SELECT COUNT(*) AS n FROM keys"
        " WHERE revoked_at IS NULL AND last_used_at >= unixepoch()-604800"
    )
    (site_yday_u, site_yday_v), (site_wk_u, site_wk_v), (site_prior_u, _) = site_traffic()

    comparable = (
        history["oldest"] is not None and history["oldest"] <= int(time.time()) - 2 * WEEK
    )
    sends_week = (
        f"- Sends **{week['sends']}** from {senders(week['senders'])}"
        f" ({week_on_week(week['sends'], prior['sends'])} vs prior 7d)"
        if comparable
        else f"- Sends **{week['sends']}** from {senders(week['senders'])}"
        " · _no prior week to compare yet_"
    )
    plural = "" if downloads_yesterday == 1 else "s"

    lines = [
        f"**{downloads_yesterday}** download{plural} and "
        f"**{day['sends']}** send{'' if day['sends'] == 1 else 's'} yesterday.",
        "",
        "**Yesterday**",
        f"- Sends **{day['sends']}** from {senders(day['senders'])}",
        f"- Downloads **{downloads_yesterday}**",
        f"- Devices **+{devices['day']}**",
        f"- Site **{site_yday_u}** visitors · {site_yday_v} page loads incl. bots",
        "",
        "**This week**",
        sends_week,
        f"- Downloads **{downloads_week}**"
        f" ({week_on_week(downloads_week, downloads_prior)} vs prior 7d)",
        f"- Site **{site_wk_u}** visitors ({week_on_week(site_wk_u, site_prior_u)} vs prior 7d)"
        f" · {site_wk_v} page loads incl. bots",
        f"- Devices **+{devices['week']}** · {devices['total']} total",
        f"- Active keys **{active_keys['n']}**",
        f"- Reviews **+{reviews['week']}** · {reviews['total']} total",
    ]
    if countries:
        lines.append("- From " + " · ".join(f"{c} {n}" for c, n in countries.most_common(4)))

    title = (
        f"notifi · {downloads_yesterday} download{plural}, "
        f"{day['sends']} send{'' if day['sends'] == 1 else 's'}"
    )
    return title, "\n".join(lines)


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
