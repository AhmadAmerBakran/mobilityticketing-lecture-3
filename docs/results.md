# Reporting lab results

The tests use the seeded data for 29 April 2026 and then run the cases in `database/postgres/experiments/reporting_cases.sql` in order. `payments` is treated as the authority.

## Baseline

The base query returns 36 DKK and one captured payment for each operator. The SQL function returns the same values. The materialized view also matches after its first refresh.

The trigger summary is different at baseline because the trigger was created after the seed data and there is no backfill. It contains no rows until a new captured payment is inserted.

| Approach | OP-METRO amount | OP-METRO count | OP-BUS amount | OP-BUS count |
| --- | ---: | ---: | ---: | ---: |
| Direct query | 36 | 1 | 36 | 1 |
| Function | 36 | 1 | 36 | 1 |
| Materialized view | 36 | 1 | 36 | 1 |
| Trigger summary | 0 | 0 | 0 | 0 |

## Test sequence

The table below follows OP-METRO because all test writes use `TICKET-1`.

| Case | Direct query | Function | Materialized view | Trigger summary |
| --- | --- | --- | --- | --- |
| Baseline | 36 / 1 | 36 / 1 | 36 / 1 | 0 / 0 |
| Captured insert, +36 | 72 / 2 | 72 / 2 | 36 / 1 | 36 / 1 |
| Failed insert, +50 | 72 / 2 | 72 / 2 | 36 / 1 | 36 / 1 |
| Failed -> Captured | 122 / 3 | 122 / 3 | 36 / 1 | 36 / 1 |
| Captured -> Refunded | 86 / 2 | 86 / 2 | 36 / 1 | 36 / 1 |
| Delete corrected payment | 36 / 1 | 36 / 1 | 36 / 1 | 36 / 1 |
| Duplicate external reference | 72 / 2 | 72 / 2 | 36 / 1 | 72 / 2 |

Amounts are shown as `amount / captured payment count`.

The delete case is a useful warning: the direct result and trigger summary happen to show the same number again, but for different reasons. The trigger still contains the 36 DKK added by `PAY-CASE-CAPTURED` even though that payment was changed to `Refunded`. Equal totals do not prove that the summary is correct.

## Disagreement example

Immediately after inserting `PAY-CASE-CAPTURED`, the direct query and function show 72 DKK for OP-METRO. The materialized view still shows 36 DKK because it has not been refreshed. The trigger summary shows 36 DKK because it only knows about the new insert and did not backfill the existing captured payment.

This is the clearest difference in execution timing:

- direct query and function read the current base tables;
- materialized view is current only at refresh time;
- trigger summary changes during the payment write, but only for cases handled by the trigger.

## Corrections and duplicate delivery

The supplied trigger only handles `INSERT`. It does not add revenue when a payment changes from `Failed` to `Captured`, and it does not remove revenue when a captured payment becomes `Refunded` or is deleted.

The duplicate external reference insert succeeds. `external_payment_reference` is not unique in the starter schema, so all approaches that derive from `payments` count the duplicate as another captured payment. This is an ingestion/data-integrity problem rather than a reporting-query problem.

## Refresh and rebuild

`daily_captured_revenue` is rebuilt with:

```sql
refresh materialized view daily_captured_revenue;
```

The trigger-maintained table can be rebuilt from the authority with `database/postgres/queries/rebuild_daily_revenue_summary.sql`. After a rebuild, it agrees with the base query for the current source data.

## Side-effect trace for a captured payment insert

For the `PAY-CASE-CAPTURED` insert:

1. PostgreSQL checks the `payments` primary key. The starter table has no foreign key from `payments.ticket_id` and no unique constraint on `external_payment_reference`.
2. The row is inserted into `payments`.
3. The `payments_daily_revenue_after_insert` trigger fires in the same transaction.
4. The trigger reads `tickets`, `trips` and `routes` to find the operator for the ticket.
5. Because the new status is `Captured`, it inserts or updates one row in `daily_revenue_by_operator`.
6. If the trigger fails, the payment insert fails with the transaction. If it succeeds, both changes commit together.
7. After commit, the direct query and function see the new payment. The trigger summary also contains its side effect. The materialized view remains unchanged until refresh.

The application explicitly issued one `INSERT`, but the trigger caused an additional lookup and summary write. That extra write is not visible in the original statement.

## Responsibility matrix

| Approach | Authority | Correctness in tested cases | Freshness | Write cost | Read cost | Hidden side effects | Rebuild path | Operational complexity |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Direct query | `payments` | Correct | Current at query time | None beyond source write | Highest of the four | None | Run the query again | Low |
| SQL function | `payments` | Correct | Current at query time | None beyond source write | Similar to direct query | None | Call the function again | Low |
| Materialized view | `payments` | Correct after refresh | Refresh-time | No extra payment write; refresh has separate cost | Low | None on payment write | `REFRESH MATERIALIZED VIEW` | Medium |
| Trigger summary | `payments` | Incorrect for backfill, corrections and deletes with supplied trigger | Immediate only for handled inserts | Extra lookup and summary write | Low | High | Truncate and rebuild from base tables | High |

## Recommendation

For the current daily reporting workload, use `payments` as the authority and the materialized view as the reporting read model. Daily revenue does not need to add hidden work to every payment write, and the materialized view has a simple rebuild path. Refresh it after the payment reconciliation step or before the daily report is produced.

Keep the direct aggregate query as the reference definition used to verify or rebuild derived results. The SQL function is useful if callers need the same calculation on demand for one operator and day, but it does not change the cost of calculating the aggregate.

The supplied trigger summary should not be the reporting authority. Making it correct would require handling inserts, status transitions, deletes, initial backfill and duplicate delivery, while also adding coupling to the payment write path. If the reporting requirement later becomes near-real-time and read volume makes the materialized view refresh unsuitable, that trade-off can be revisited.
