-- ============================================================
-- SISTEMAIA · Migración incremental (Etapas 2-6)
-- Ejecutar en Supabase SQL Editor SOLO si ya corriste schema.sql antes.
-- Si es tu primera vez, ejecuta schema.sql completo en su lugar.
-- ============================================================

-- 1) Control de visibilidad de módulos por cliente
alter table public.perfiles
  add column if not exists modulos_visibles jsonb not null default
    '["panel","encuesta","sesiones","archivos","citas","qr"]'::jsonb;

-- 2) Log de recordatorios enviados (correo / WhatsApp / simulado)
create table if not exists public.recordatorios_log (
  id          uuid primary key default gen_random_uuid(),
  cita_id     uuid references public.citas(id) on delete cascade,
  cliente_id  uuid references public.perfiles(id) on delete cascade,
  canal       text not null check (canal in ('email', 'whatsapp', 'simulado')),
  destino     text,
  estado      text not null default 'enviado' check (estado in ('enviado', 'fallido', 'simulado')),
  detalle     text,
  created_at  timestamptz not null default now()
);

alter table public.recordatorios_log enable row level security;

drop policy if exists "recordatorios_admin" on public.recordatorios_log;
create policy "recordatorios_admin" on public.recordatorios_log
  for all using (public.es_admin()) with check (public.es_admin());

-- 3) Verificación rápida (opcional): debe devolver 2 columnas/1 tabla
-- select column_name from information_schema.columns
--   where table_name = 'perfiles' and column_name = 'modulos_visibles';
-- select count(*) from public.recordatorios_log;
