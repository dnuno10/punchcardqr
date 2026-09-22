-- PunchCardQR · 0006 · Scheduled maintenance (pg_cron)
create extension if not exists pg_cron;

select cron.schedule('expire-rewards',    '*/15 * * * *', $$select public.expire_rewards()$$);
select cron.schedule('purge-rate-limits', '0 3 * * *',    $$select public.purge_rate_limits()$$);
