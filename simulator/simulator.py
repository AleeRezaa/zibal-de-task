"""Paymentyar change simulator: applies realistic OLTP changes to the core schema."""

import logging
import os
import random
import time
from collections import deque

import psycopg

DSN = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@source-db:5432/paymentyar")
TPS = int(os.getenv("TXN_PER_SECOND", "20"))
SCHEMA_CHANGE_AFTER = int(os.getenv("SCHEMA_CHANGE_AFTER_SECONDS", "600"))
MERCHANT_CHANGE_EVERY = 60
TEST_TXN_EVERY = 30
TEST_BIN = "999999"

CHANNELS = ["POS"] * 6 + ["IPG"] * 3 + ["QR"]
BINS = ["603799", "589210", "627648", "627961", "603770", "628023", "627760", "502229"]
PROVINCES = [
    "Tehran",
    "Isfahan",
    "Khorasan Razavi",
    "Fars",
    "East Azerbaijan",
    "Khuzestan",
    "Alborz",
    "Mazandaran",
    "Gilan",
    "Kerman",
    "Yazd",
    "Qom",
]
RISK_LEVELS = ["LOW", "MEDIUM", "HIGH"]

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("simulator")


def connect() -> psycopg.Connection:
    while True:
        try:
            return psycopg.connect(DSN, autocommit=True)
        except psycopg.OperationalError:
            log.info("waiting for database ...")
            time.sleep(3)


def random_amount() -> int:
    return int(round(10_000 * 5000 ** random.random(), -3))  # 10k .. 50M IRR


class Simulator:
    def __init__(self, conn: psycopg.Connection):
        self.conn = conn
        self.started = time.monotonic()
        self.pending: deque = deque()  # (due_at, txn_id)
        self.to_reverse: deque = deque()  # (due_at, txn_id)
        self.test_rows: deque = deque()  # (due_at, txn_id)
        self.last_merchant_change = 0.0
        self.last_test_txn = 0.0
        self.max_merchant_id = conn.execute("SELECT max(merchant_id) FROM core.merchants").fetchone()[0]
        self.has_installments = self._installments_exists()
        self._cleanup_after_restart()

    def _installments_exists(self) -> bool:
        return (
            self.conn.execute(
                "SELECT 1 FROM information_schema.columns "
                "WHERE table_schema='core' AND table_name='transactions' AND column_name='installments'"
            ).fetchone()
            is not None
        )

    def _cleanup_after_restart(self):
        self.conn.execute("DELETE FROM core.transactions WHERE card_bin = %s", (TEST_BIN,))
        self.conn.execute(
            "UPDATE core.transactions SET status = CASE WHEN random() < 0.89 THEN 'SUCCESS' ELSE 'FAILED' END, "
            "updated_at = now() WHERE status = 'PENDING'"
        )

    # ---------------------------------------------------------------- actions
    def insert_transactions(self, now: float):
        merchants, channels, bins, amounts, fees, installments = [], [], [], [], [], []
        for _ in range(TPS):
            channel = random.choice(CHANNELS)
            amount = random_amount()
            merchants.append(random.randint(1, self.max_merchant_id))
            channels.append(channel)
            bins.append(random.choice(BINS))
            amounts.append(amount)
            fees.append(max(amount * 2 // 1000, 1000))
            installments.append(random.choice([1, 3, 6, 12]) if channel == "IPG" else 1)

        if self.has_installments:
            sql = (
                "INSERT INTO core.transactions (merchant_id, channel, card_bin, amount, fee_amount, status, installments) "
                "SELECT m, c, b, a, f, 'PENDING', i FROM unnest(%s::bigint[], %s::text[], %s::text[], "
                "%s::bigint[], %s::bigint[], %s::smallint[]) AS t(m, c, b, a, f, i) RETURNING transaction_id"
            )
            params = (merchants, channels, bins, amounts, fees, installments)
        else:
            sql = (
                "INSERT INTO core.transactions (merchant_id, channel, card_bin, amount, fee_amount, status) "
                "SELECT m, c, b, a, f, 'PENDING' FROM unnest(%s::bigint[], %s::text[], %s::text[], "
                "%s::bigint[], %s::bigint[]) AS t(m, c, b, a, f) RETURNING transaction_id"
            )
            params = (merchants, channels, bins, amounts, fees)

        for (txn_id,) in self.conn.execute(sql, params).fetchall():
            self.pending.append((now + random.uniform(2, 8), txn_id))

    def settle_pending(self, now: float):
        success, failed = [], []
        while self.pending and self.pending[0][0] <= now:
            _, txn_id = self.pending.popleft()
            (success if random.random() < 0.89 else failed).append(txn_id)
        for status, ids in (("SUCCESS", success), ("FAILED", failed)):
            if ids:
                self.conn.execute(
                    "UPDATE core.transactions SET status = %s, updated_at = now() WHERE transaction_id = ANY(%s)",
                    (status, ids),
                )
        for txn_id in success:
            if random.random() < 0.11:
                self.to_reverse.append((now + random.uniform(15, 60), txn_id))

    def reverse_due(self, now: float):
        # to_reverse is not strictly sorted (random delays); sort before draining
        self.to_reverse = deque(sorted(self.to_reverse))
        ids = []
        while self.to_reverse and self.to_reverse[0][0] <= now:
            ids.append(self.to_reverse.popleft()[1])
        if ids:
            self.conn.execute(
                "UPDATE core.transactions SET status = 'REVERSED', updated_at = now() WHERE transaction_id = ANY(%s)",
                (ids,),
            )

    def change_merchant(self, now: float):
        if now - self.last_merchant_change < MERCHANT_CHANGE_EVERY:
            return
        self.last_merchant_change = now
        merchant_id = random.randint(1, self.max_merchant_id)
        risk, province = self.conn.execute(
            "SELECT risk_level, province FROM core.merchants WHERE merchant_id = %s", (merchant_id,)
        ).fetchone()
        new_risk = random.choice([r for r in RISK_LEVELS if r != risk])
        new_province = random.choice([p for p in PROVINCES if p != province])
        self.conn.execute(
            "UPDATE core.merchants SET risk_level = %s, province = %s, updated_at = now() WHERE merchant_id = %s",
            (new_risk, new_province, merchant_id),
        )
        log.info("merchant %s: %s/%s -> %s/%s", merchant_id, risk, province, new_risk, new_province)

    def test_transactions(self, now: float):
        if now - self.last_test_txn >= TEST_TXN_EVERY:
            self.last_test_txn = now
            txn_id = self.conn.execute(
                "INSERT INTO core.transactions (merchant_id, channel, card_bin, amount, fee_amount, status) "
                "VALUES (1, 'IPG', %s, 10000, 1000, 'PENDING') RETURNING transaction_id",
                (TEST_BIN,),
            ).fetchone()[0]
            self.test_rows.append((now + random.uniform(5, 15), txn_id))
        while self.test_rows and self.test_rows[0][0] <= now:
            _, txn_id = self.test_rows.popleft()
            self.conn.execute("DELETE FROM core.transactions WHERE transaction_id = %s", (txn_id,))
            log.info("hard-deleted test transaction %s", txn_id)

    def schema_change(self, now: float):
        if not self.has_installments and now - self.started >= SCHEMA_CHANGE_AFTER:
            self.conn.execute("ALTER TABLE core.transactions ADD COLUMN IF NOT EXISTS installments SMALLINT")
            self.has_installments = True
            log.warning("SCHEMA CHANGE: added core.transactions.installments")

    # ---------------------------------------------------------------- loop
    def tick(self):
        now = time.monotonic()
        self.schema_change(now)
        self.insert_transactions(now)
        self.settle_pending(now)
        self.reverse_due(now)
        self.change_merchant(now)
        self.test_transactions(now)


def main():
    sim = Simulator(connect())
    log.info("simulator started: %s txn/s, schema change after %ss", TPS, SCHEMA_CHANGE_AFTER)
    while True:
        started = time.monotonic()
        try:
            sim.tick()
        except psycopg.OperationalError:
            log.exception("database error, reconnecting")
            sim = Simulator(connect())
        time.sleep(max(0.0, 1.0 - (time.monotonic() - started)))


if __name__ == "__main__":
    main()
