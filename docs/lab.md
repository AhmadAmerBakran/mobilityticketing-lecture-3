# Implementation lab: Where should reporting logic execute?

## Purpose

Implement and compare a direct SQL query, a user-defined function, a materialized view, and a trigger-maintained summary for daily captured revenue. Use the differences to decide where the responsibility belongs.

The aim is not to simply choose the option with the most or the least SQL. Make a fair comparison of the options. Take into account execution timing, dependencies, transaction scope, freshness, and recovery.

## Scenario

Operators need daily captured revenue. The initial design proposes a `daily_revenue_by_operator` table maintained when payments are inserted. Reports may also be calculated directly from the transactional tables or exposed through a materialized view.

The `payments` table is the authority for this experiment. Treat the stored reporting results as derived data.

## Before you start

Start the database from the repository root:

```bash
docker compose up -d
docker compose ps
```

Run the base query in [`../database/postgres/queries/base_revenue.sql`](../database/postgres/queries/base_revenue.sql) and save its result. Do not edit the files in `database/postgres/init/`.

## Tasks

1. Run the reference revenue query and verify its result from the base tables.
2. Wrap the read logic in a SQL function.
3. Create a materialized view and observe when it becomes stale.
4. Create the supplied trigger-maintained summary.
5. Test all four approaches against:
   - a captured payment insert;
   - a failed payment insert;
   - a status correction from `Failed` to `Captured`;
   - a correction from `Captured` to `Refunded`;
   - deletion or replacement of test data;
   - duplicate delivery of the same external payment reference.
6. Produce a responsibility matrix comparing correctness, freshness, write cost, read cost, hidden side effects, rebuildability, and operational complexity.
7. Recommend one approach for the current case. A hybrid answer is allowed, but each stored copy must have a clear authority and rebuild path.

## Required evidence

- SQL object definitions for all four approaches.
- Output before and after each test case.
- One captured example where two approaches disagree.
- A side-effect trace showing everything caused by one payment write.
- A responsibility matrix with a named authority, freshness rule, and rebuild path.
- One issue in the issue register and one defended decision record.
