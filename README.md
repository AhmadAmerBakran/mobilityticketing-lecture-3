# MobilityTicketing - lecture 3

Week 37 lab for SQL programmability and reporting. The project compares four ways of producing daily captured revenue: a direct query, a SQL function, a materialized view and a trigger-maintained summary.

## Run the database

```bash
docker compose up -d
docker compose ps
```

PostgreSQL is exposed on `localhost:5432` with database, user and password set to `mobility`.

To reset the database to the seeded state:

```bash
docker compose down
docker compose up -d
```

## Apply the reporting objects

Run the migrations in order:

```bash
docker compose exec -T postgres psql -U mobility -d mobility < database/postgres/migrations/020_reporting_function.sql
docker compose exec -T postgres psql -U mobility -d mobility < database/postgres/migrations/021_daily_revenue_trigger.sql
docker compose exec -T postgres psql -U mobility -d mobility < database/postgres/migrations/022_daily_captured_revenue.sql
```

Populate the materialized view before the first comparison:

```bash
docker compose exec -T postgres psql -U mobility -d mobility -c "refresh materialized view daily_captured_revenue;"
```

The base query is in `database/postgres/queries/base_revenue.sql`. The complete test sequence is in `database/postgres/experiments/reporting_cases.sql`.

The lab notes, results, responsibility matrix and decision are under `docs/`.
