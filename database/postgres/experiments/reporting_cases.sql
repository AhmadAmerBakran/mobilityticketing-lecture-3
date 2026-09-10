\pset pager off
\pset null '(null)'
set timezone = 'UTC';

-- The materialized view starts empty because it is created WITH NO DATA.
refresh materialized view daily_captured_revenue;

\echo 'BASELINE - direct query'
select * from (
    select r.operator_id, p.created_utc::date as revenue_date,
           sum(p.amount) as captured_amount, count(*) as captured_payments
    from payments p
    join tickets t on t.id = p.ticket_id
    join trips tr on tr.id = t.trip_id
    join routes r on r.id = tr.route_id
    where p.status = 'Captured'
    group by r.operator_id, p.created_utc::date
) x order by operator_id, revenue_date;

\echo 'BASELINE - function'
select o.id as operator_id, date '2026-04-29' as revenue_date,
       f.captured_amount, f.captured_payments
from operators o
cross join lateral captured_revenue_for_day(o.id, date '2026-04-29') f
order by o.id;

\echo 'BASELINE - materialized view'
select * from daily_captured_revenue order by operator_id, revenue_date;

\echo 'BASELINE - trigger summary'
select o.id as operator_id, date '2026-04-29' as revenue_date,
       coalesce(s.captured_amount, 0) as captured_amount,
       coalesce(s.captured_payments, 0) as captured_payments
from operators o
left join daily_revenue_by_operator s
  on s.operator_id = o.id and s.revenue_date = date '2026-04-29'
order by o.id;

-- 1. Captured payment insert
insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status, created_utc
) values (
    'PAY-CASE-CAPTURED', 'USER-1', 'TICKET-1', 'gateway-case-captured',
    36, 'DKK', 'Captured', '2026-04-29 10:00:00+00'
);

\echo 'CASE 1 - captured insert - direct/function/materialized/trigger'
select 'direct' as approach, 72::numeric as expected_amount,
       q.captured_amount, q.captured_payments
from (
    select coalesce(sum(p.amount),0) captured_amount, count(*) captured_payments
    from payments p join tickets t on t.id=p.ticket_id
    join trips tr on tr.id=t.trip_id join routes r on r.id=tr.route_id
    where r.operator_id='OP-METRO' and p.created_utc::date=date '2026-04-29'
      and p.status='Captured'
) q
union all
select 'function', 72::numeric, f.captured_amount, f.captured_payments
from captured_revenue_for_day('OP-METRO', date '2026-04-29') f
union all
select 'materialized', 72::numeric, coalesce(m.captured_amount,0), coalesce(m.captured_payments,0)
from (select 1) x left join daily_captured_revenue m
  on m.operator_id='OP-METRO' and m.revenue_date=date '2026-04-29'
union all
select 'trigger', 72::numeric, coalesce(s.captured_amount,0), coalesce(s.captured_payments,0)
from (select 1) x left join daily_revenue_by_operator s
  on s.operator_id='OP-METRO' and s.revenue_date=date '2026-04-29';

-- 2. Failed payment insert
insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status, created_utc
) values (
    'PAY-CASE-FAILED', 'USER-1', 'TICKET-1', 'gateway-case-failed',
    50, 'DKK', 'Failed', '2026-04-29 10:05:00+00'
);

\echo 'CASE 2 - failed insert'
select 'direct' as approach, q.captured_amount, q.captured_payments
from (select coalesce(sum(p.amount),0) captured_amount, count(*) captured_payments
      from payments p join tickets t on t.id=p.ticket_id join trips tr on tr.id=t.trip_id join routes r on r.id=tr.route_id
      where r.operator_id='OP-METRO' and p.created_utc::date=date '2026-04-29' and p.status='Captured') q
union all select 'function', f.captured_amount, f.captured_payments from captured_revenue_for_day('OP-METRO', date '2026-04-29') f
union all select 'materialized', coalesce(m.captured_amount,0), coalesce(m.captured_payments,0) from (select 1) x left join daily_captured_revenue m on m.operator_id='OP-METRO' and m.revenue_date=date '2026-04-29'
union all select 'trigger', coalesce(s.captured_amount,0), coalesce(s.captured_payments,0) from (select 1) x left join daily_revenue_by_operator s on s.operator_id='OP-METRO' and s.revenue_date=date '2026-04-29';

-- 3. Failed -> Captured
update payments set status = 'Captured' where id = 'PAY-CASE-FAILED';

\echo 'CASE 3 - Failed to Captured'
select 'direct' as approach, q.captured_amount, q.captured_payments
from (select coalesce(sum(p.amount),0) captured_amount, count(*) captured_payments
      from payments p join tickets t on t.id=p.ticket_id join trips tr on tr.id=t.trip_id join routes r on r.id=tr.route_id
      where r.operator_id='OP-METRO' and p.created_utc::date=date '2026-04-29' and p.status='Captured') q
union all select 'function', f.captured_amount, f.captured_payments from captured_revenue_for_day('OP-METRO', date '2026-04-29') f
union all select 'materialized', coalesce(m.captured_amount,0), coalesce(m.captured_payments,0) from (select 1) x left join daily_captured_revenue m on m.operator_id='OP-METRO' and m.revenue_date=date '2026-04-29'
union all select 'trigger', coalesce(s.captured_amount,0), coalesce(s.captured_payments,0) from (select 1) x left join daily_revenue_by_operator s on s.operator_id='OP-METRO' and s.revenue_date=date '2026-04-29';

-- 4. Captured -> Refunded
update payments set status = 'Refunded' where id = 'PAY-CASE-CAPTURED';

\echo 'CASE 4 - Captured to Refunded'
select 'direct' as approach, q.captured_amount, q.captured_payments
from (select coalesce(sum(p.amount),0) captured_amount, count(*) captured_payments
      from payments p join tickets t on t.id=p.ticket_id join trips tr on tr.id=t.trip_id join routes r on r.id=tr.route_id
      where r.operator_id='OP-METRO' and p.created_utc::date=date '2026-04-29' and p.status='Captured') q
union all select 'function', f.captured_amount, f.captured_payments from captured_revenue_for_day('OP-METRO', date '2026-04-29') f
union all select 'materialized', coalesce(m.captured_amount,0), coalesce(m.captured_payments,0) from (select 1) x left join daily_captured_revenue m on m.operator_id='OP-METRO' and m.revenue_date=date '2026-04-29'
union all select 'trigger', coalesce(s.captured_amount,0), coalesce(s.captured_payments,0) from (select 1) x left join daily_revenue_by_operator s on s.operator_id='OP-METRO' and s.revenue_date=date '2026-04-29';

-- 5. Delete test data
 delete from payments where id = 'PAY-CASE-FAILED';

\echo 'CASE 5 - delete captured test payment'
select 'direct' as approach, q.captured_amount, q.captured_payments
from (select coalesce(sum(p.amount),0) captured_amount, count(*) captured_payments
      from payments p join tickets t on t.id=p.ticket_id join trips tr on tr.id=t.trip_id join routes r on r.id=tr.route_id
      where r.operator_id='OP-METRO' and p.created_utc::date=date '2026-04-29' and p.status='Captured') q
union all select 'function', f.captured_amount, f.captured_payments from captured_revenue_for_day('OP-METRO', date '2026-04-29') f
union all select 'materialized', coalesce(m.captured_amount,0), coalesce(m.captured_payments,0) from (select 1) x left join daily_captured_revenue m on m.operator_id='OP-METRO' and m.revenue_date=date '2026-04-29'
union all select 'trigger', coalesce(s.captured_amount,0), coalesce(s.captured_payments,0) from (select 1) x left join daily_revenue_by_operator s on s.operator_id='OP-METRO' and s.revenue_date=date '2026-04-29';

-- 6. Duplicate external payment reference. This succeeds because the starter schema
-- does not have a unique constraint on external_payment_reference.
insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status, created_utc
) values (
    'PAY-CASE-DUPLICATE', 'USER-1', 'TICKET-1', 'gateway-capture-0001',
    36, 'DKK', 'Captured', '2026-04-29 10:10:00+00'
);

\echo 'CASE 6 - duplicate external reference'
select 'direct' as approach, q.captured_amount, q.captured_payments
from (select coalesce(sum(p.amount),0) captured_amount, count(*) captured_payments
      from payments p join tickets t on t.id=p.ticket_id join trips tr on tr.id=t.trip_id join routes r on r.id=tr.route_id
      where r.operator_id='OP-METRO' and p.created_utc::date=date '2026-04-29' and p.status='Captured') q
union all select 'function', f.captured_amount, f.captured_payments from captured_revenue_for_day('OP-METRO', date '2026-04-29') f
union all select 'materialized', coalesce(m.captured_amount,0), coalesce(m.captured_payments,0) from (select 1) x left join daily_captured_revenue m on m.operator_id='OP-METRO' and m.revenue_date=date '2026-04-29'
union all select 'trigger', coalesce(s.captured_amount,0), coalesce(s.captured_payments,0) from (select 1) x left join daily_revenue_by_operator s on s.operator_id='OP-METRO' and s.revenue_date=date '2026-04-29';

\echo 'REFRESH MATERIALIZED VIEW'
refresh materialized view daily_captured_revenue;
select * from daily_captured_revenue order by operator_id, revenue_date;

\echo 'REBUILD TRIGGER SUMMARY FROM AUTHORITY'
truncate table daily_revenue_by_operator;
insert into daily_revenue_by_operator (operator_id, revenue_date, captured_amount, captured_payments)
select r.operator_id, p.created_utc::date, sum(p.amount), count(*)
from payments p
join tickets t on t.id=p.ticket_id
join trips tr on tr.id=t.trip_id
join routes r on r.id=tr.route_id
where p.status='Captured'
group by r.operator_id, p.created_utc::date;
select * from daily_revenue_by_operator order by operator_id, revenue_date;
