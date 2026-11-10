"""Times each card on both dashboards and checks that their results match."""

import datetime
import os
import statistics
import time

from setup import CARDS, MB, login, wait_for_metabase

RUNS = int(os.getenv("BENCH_RUNS", "5"))
WAIT = int(os.getenv("BENCH_WAIT_SECONDS", "0"))  # let CDC + dbt catch up first
OUT = os.getenv("BENCH_OUT", "/out/benchmark.md")


def dashboard_cards(s, name) -> dict:
    dash = next(d for d in s.get(f"{MB}/api/dashboard").json() if d["name"] == name)
    detail = s.get(f"{MB}/api/dashboard/{dash['id']}").json()
    return {dc["card"]["name"]: dc["card_id"] for dc in detail["dashcards"]}


def run(s, card_id):
    start = time.perf_counter()
    r = s.post(f"{MB}/api/card/{card_id}/query", json={"ignore_cache": True})
    elapsed_ms = (time.perf_counter() - start) * 1000
    r.raise_for_status()
    body = r.json()
    if body.get("status") != "completed":
        raise RuntimeError(body.get("error"))
    return elapsed_ms, body


def normalize(v):
    if isinstance(v, str) and len(v) >= 10 and v[4] == "-" and v[7] == "-":
        return v[:10]  # '2026-11-10T00:00:00Z' -> '2026-11-10'
    if isinstance(v, float):
        return round(v, 2)
    return v


def rows(body):
    return sorted(tuple(normalize(x) for x in row) for row in body["data"]["rows"])


def measure(s, card_id):
    cold, body = run(s, card_id)  # first run: cold caches
    warm = [run(s, card_id)[0] for _ in range(RUNS)]
    return cold, statistics.median(warm), rows(body)


def compare(a, b) -> str:
    sa, sb = set(a), set(b)
    if sa == sb:
        return "identical"
    return f"{len(sa - sb)} rows only in core, {len(sb - sa)} only in reporting"


def main():
    wait_for_metabase()
    s = login()
    if WAIT:
        print(f"waiting {WAIT} s for CDC and dbt to catch up ...")
        time.sleep(WAIT)
    before = dashboard_cards(s, "Daily Sales")
    after = dashboard_cards(s, "Daily Sales (Optimized)")

    lines = [
        "# Metabase card benchmark",
        "",
        f"Run at {datetime.datetime.now(datetime.timezone.utc):%Y-%m-%d %H:%M UTC}, "
        f"median of {RUNS} warm runs, cache bypassed, simulator paused.",
        "",
        "| Card | Before cold (ms) | Before warm (ms) | After cold (ms) | After warm (ms) | Speed-up | Results |",
        "| --- | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for _, title, *_ in CARDS:
        b_cold, b_warm, b_rows = measure(s, before[title])
        a_cold, a_warm, a_rows = measure(s, after[title])
        lines.append(
            f"| {title} | {b_cold:.0f} | {b_warm:.0f} | {a_cold:.0f} | {a_warm:.0f} "
            f"| {b_warm / a_warm:.0f}x | {compare(b_rows, a_rows)} |"
        )
        print(lines[-1])

    with open(OUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"written to {OUT}")


if __name__ == "__main__":
    main()
