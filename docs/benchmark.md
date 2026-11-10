# Metabase card benchmark

Run at 2026-11-10 21:30 UTC, median of 5 warm runs, cache bypassed, simulator paused.

| Card | Before cold (ms) | Before warm (ms) | After cold (ms) | After warm (ms) | Speed-up | Results |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| 1. Daily successful amount & count (90 days) | 3753 | 3683 | 74 | 67 | 55x | identical |
| 2. Daily success rate by channel (30 days) | 3598 | 3475 | 61 | 71 | 49x | identical |
| 3. Top 10 merchants, current month | 2821 | 2734 | 64 | 64 | 42x | identical |
| 4. Fee by MCC and province (90 days) | 3459 | 3197 | 83 | 90 | 36x | 75 rows only in core, 75 only in reporting |
| 5. Monthly successful volume by risk level | 4316 | 4220 | 61 | 64 | 66x | 21 rows only in core, 21 only in reporting |
