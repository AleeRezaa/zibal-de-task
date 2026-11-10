"""Creates or updates the Metabase admin, database connections and the two dashboards.

Re-running it is safe: existing cards get the latest SQL and chart settings.
"""

import os
import pathlib
import time

import requests

MB = os.getenv("MB_URL", "http://metabase:3000")
EMAIL = os.getenv("MB_ADMIN_EMAIL", "admin@paymentyar.local")
PASSWORD = os.getenv("MB_ADMIN_PASSWORD", "Paymentyar123!")
QUERIES = pathlib.Path(__file__).parent / "queries"

# (file stem, card title, visualization, chart settings)
CARDS = [
    (
        "01_daily_success",
        "1. Daily successful amount & count (90 days)",
        "line",
        {
            "graph.dimensions": ["day"],
            "graph.metrics": ["success_amount", "success_count"],
            "series_settings": {"success_count": {"axis": "right"}},
        },
    ),
    (
        "02_success_rate_by_channel",
        "2. Daily success rate by channel (30 days)",
        "line",
        {"graph.dimensions": ["day", "channel"], "graph.metrics": ["success_rate_pct"]},
    ),
    ("03_top_merchants_month", "3. Top 10 merchants, current month", "table", {}),
    ("04_fee_by_mcc_province", "4. Fee by MCC and province (90 days)", "table", {}),
    (
        "05_monthly_by_risk",
        "5. Monthly successful volume by risk level",
        "bar",
        {
            "graph.dimensions": ["month", "risk_level"],
            "graph.metrics": ["success_amount"],
            "stackable.stack_type": "stacked",
        },
    ),
]
DASHBOARDS = {"Daily Sales": "core", "Daily Sales (Optimized)": "reporting"}


def wait_for_metabase():
    while True:
        try:
            if requests.get(f"{MB}/api/health", timeout=5).json().get("status") == "ok":
                return
        except requests.RequestException:
            pass
        print("waiting for Metabase ...")
        time.sleep(5)


def login() -> requests.Session:
    s = requests.Session()
    props = s.get(f"{MB}/api/session/properties").json()
    if not props.get("has-user-setup"):
        s.post(
            f"{MB}/api/setup",
            json={
                "token": props["setup-token"],
                "user": {
                    "email": EMAIL,
                    "password": PASSWORD,
                    "first_name": "Admin",
                    "last_name": "Paymentyar",
                    "site_name": "Paymentyar",
                },
                "prefs": {"site_name": "Paymentyar", "allow_tracking": False},
            },
        ).raise_for_status()
    r = s.post(f"{MB}/api/session", json={"username": EMAIL, "password": PASSWORD})
    r.raise_for_status()
    s.headers["X-Metabase-Session"] = r.json()["id"]
    return s


def get_or_create_db(s, name, engine, details) -> int:
    for db in s.get(f"{MB}/api/database").json()["data"]:
        if db["name"] == name:
            return db["id"]
    r = s.post(f"{MB}/api/database", json={"name": name, "engine": engine, "details": details})
    r.raise_for_status()
    return r.json()["id"]


def card_body(db_id, folder, stem, title, display, viz) -> dict:
    return {
        "name": title,
        "display": display,
        "visualization_settings": viz,
        "dataset_query": {
            "type": "native",
            "database": db_id,
            "native": {"query": (QUERIES / folder / f"{stem}.sql").read_text()},
        },
    }


def upsert_dashboard(s, name, db_id, folder) -> int:
    existing = next((d for d in s.get(f"{MB}/api/dashboard").json() if d["name"] == name), None)

    if existing:  # update SQL + chart settings of the cards already on it
        detail = s.get(f"{MB}/api/dashboard/{existing['id']}").json()
        card_ids = {dc["card"]["name"]: dc["card_id"] for dc in detail["dashcards"]}
        for stem, title, display, viz in CARDS:
            if title in card_ids:
                s.put(
                    f"{MB}/api/card/{card_ids[title]}", json=card_body(db_id, folder, stem, title, display, viz)
                ).raise_for_status()
        return existing["id"]

    dash_id = s.post(f"{MB}/api/dashboard", json={"name": name}).json()["id"]
    dashcards = []
    for i, (stem, title, display, viz) in enumerate(CARDS):
        card = s.post(f"{MB}/api/card", json=card_body(db_id, folder, stem, title, display, viz)).json()
        dashcards.append(
            {"id": -(i + 1), "card_id": card["id"], "row": (i // 2) * 6, "col": (i % 2) * 12, "size_x": 12, "size_y": 6}
        )
    s.put(f"{MB}/api/dashboard/{dash_id}", json={"dashcards": dashcards}).raise_for_status()
    return dash_id


def main():
    wait_for_metabase()
    s = login()
    db_ids = {
        "core": get_or_create_db(
            s,
            "Paymentyar Core (OLTP)",
            "postgres",
            {
                "host": "source-db",
                "port": 5432,
                "dbname": "paymentyar",
                "user": "analytics_ro",
                "password": "analytics_ro",
            },
        ),
        "reporting": get_or_create_db(
            s,
            "Paymentyar Analytics",
            "clickhouse",
            {"host": "clickhouse", "port": 8123, "dbname": "reporting", "user": "metabase", "password": "metabase"},
        ),
    }
    for name, folder in DASHBOARDS.items():
        upsert_dashboard(s, name, db_ids[folder], folder)
    print("Metabase ready: http://localhost:3000")


if __name__ == "__main__":
    main()
