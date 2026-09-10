# Issue register

| ID | Issue | Impact | Evidence | Suggested follow-up |
| --- | --- | --- | --- | --- |
| REP-01 | Duplicate external payment references are accepted | A repeated gateway delivery can be counted as new captured revenue | The test insert using `gateway-capture-0001` succeeds because `external_payment_reference` has no unique constraint | Make payment ingestion idempotent, for example with a unique gateway reference after the expected ownership and retry rules are defined |
