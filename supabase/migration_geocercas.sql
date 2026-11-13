-- ============================================================
-- SISTEMAIA · Módulo Geocercas
-- Crea tabla geocercas y agrega el módulo a perfiles
-- ============================================================

-- ---------- Tabla geocercas ----------
create table public.geocercas (
  id          uuid primary key default gen_random_uuid(),
  cliente_id  uuid not null references public.perfiles(id) on delete cascade,
  nombre      text not null,
  tipo        text not null check (tipo in ('circulo', 'poligono')),
  geometria   jsonb not null,  -- circulo: { centro: [lat,lng], radio_m: n } | poligono: { coordenadas: [[lat,lng],...] }
  color       text default '#3b82f6',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Índice para búsquedas rápidas por cliente
create index idx_geocercas_cliente on public.geocercas(cliente_id);

-- Row Level Security para geocercas
alter table public.geocercas enable row level security;

-- Cada cliente ve/solo sus geocercas; admin ve todas
create policy "geocercas_select" on public.geocercas
  for select using (cliente_id = auth.uid() or public.es_admin());
create policy "geocercas_insert" on public.geocercas
  for insert with check (cliente_id = auth.uid() or public.es_admin());
create policy "geocercas_update" on public.geocercas
  for update using (cliente_id = auth.uid() or public.es_admin());
create policy "geocercas_delete" on public.geocercas
  for delete using (cliente_id = auth.uid() or public.es_admin());

-- Trigger para updated_at
create or replace function public.actualizar_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trigger_geocercas_updated_at on public.geocercas;
create trigger trigger_geocercas_updated_at
  before update on public.geocercas
  for each row execute function public.actualizar_updated_at();

-- ---------- Agregar 'geocercas' a módulos visibles ----------
alter table public.perfiles
  alter column modulos_visibles set default
    '["panel","encuesta","sesiones","archivos","citas","qr","geocercas"]'::jsonb;

update public.perfiles
set modulos_visibles = modulos_visibles || '["geocercas"]'::jsonb
where jsonb_typeof(modulos_visibles) = 'array'
  and not (modulos_visibles @> '["geocercas"]'::jsonb);
