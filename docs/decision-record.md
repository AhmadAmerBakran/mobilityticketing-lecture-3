# Decision: daily captured revenue reporting

## Context

The report is a daily aggregate over captured payments. The experiment compares a direct query, a SQL function, a materialized view and a trigger-maintained summary. Corrections, refunds, deletes and duplicate delivery are part of the test because they change whether a stored aggregate can still be trusted.

## Decision

Use `payments` as the authority and `daily_captured_revenue` as the read model for the daily report. Refresh the materialized view after payment reconciliation or directly before the report is produced.

Keep the direct aggregate query as the reference calculation. It is also the definition used to check a refreshed or rebuilt result.

Do not use `daily_revenue_by_operator` as an authority. The supplied insert trigger does not cover the full payment lifecycle, and extending it would put more reporting responsibility on the payment write path.

## Why

The report is read as a daily summary, so a controlled refresh point is acceptable. A materialized view keeps report reads cheap without adding a hidden write for every payment operation. If it becomes stale or incorrect, it can be rebuilt directly from `payments`.

The trigger summary has cheaper reads and can update immediately for the event it handles, but the tests show that immediate is not the same as correct. Status corrections and deletes leave it out of sync unless more trigger logic is added. Duplicate delivery also needs to be solved at the payment boundary rather than inside the reporting aggregate.

## Consequences

The report has a defined freshness rule instead of pretending to be real-time. Operations need to run or schedule the refresh before the daily report. If a later requirement needs near-real-time revenue with very high read volume, the decision should be reviewed with concurrency, idempotency and recovery included in the design.
