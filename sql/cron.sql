-- Einmal zusätzlich zu sql/schema.sql im Supabase SQL Editor ausführen.
-- Das aktiviert die tägliche Bereinigung vergessener Sessions um 03:30 UTC.
-- Der Job löscht ausschließlich Sessions, die älter als 30 Tage sind.
create extension if not exists pg_cron;

do $$
declare existing_job bigint;
begin
  select jobid into existing_job from cron.job where jobname='mindmap-cleanup' limit 1;
  if existing_job is not null then perform cron.unschedule(existing_job); end if;
  perform cron.schedule('mindmap-cleanup','30 3 * * *',$cron$select public.cleanup_old_mindmap_sessions();$cron$);
end $$;
