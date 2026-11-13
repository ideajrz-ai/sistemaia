-- ============================================================
-- SISTEMAIA · Reparación completa e IDEMPOTENTE del esquema
-- Ejecutar en Supabase SQL Editor. Se puede correr las veces
-- que sea necesario sin romper nada.
-- ============================================================

-- ---------- 0) Recargar caché de PostgREST ----------
notify pgrst, 'reload schema';

-- ---------- 1) Funciones y triggers ----------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.perfiles (id, nombre, email, telefono, direccion, necesidad)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data->>'nombre', ''),
      nullif(new.raw_user_meta_data->>'full_name', ''),
      nullif(new.raw_user_meta_data->>'name', ''),
      ''
    ),
    new.email,
    coalesce(new.raw_user_meta_data->>'telefono', ''),
    coalesce(new.raw_user_meta_data->>'direccion', ''),
    coalesce(new.raw_user_meta_data->>'necesidad', '')
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.proteger_rol()
returns trigger
language plpgsql
as $$
begin
  if new.rol is distinct from old.rol then
    if auth.uid() = old.id then
      raise exception 'No puedes modificar tu propio rol';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists proteger_rol_perfil on public.perfiles;
create trigger proteger_rol_perfil
  before update on public.perfiles
  for each row execute function public.proteger_rol();

create or replace function public.es_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.perfiles
    where id = auth.uid() and rol = 'admin'
  );
$$;

-- ---------- 2) RLS: activar en todas las tablas ----------
alter table public.perfiles            enable row level security;
alter table public.preguntas_encuesta   enable row level security;
alter table public.encuestas           enable row level security;
alter table public.respuestas_encuesta  enable row level security;
alter table public.sesiones            enable row level security;
alter table public.archivos            enable row level security;
alter table public.citas               enable row level security;
alter table public.qr_accesos          enable row level security;
alter table public.recordatorios_log   enable row level security;

-- ---------- 3) Políticas (drop + create = idempotente) ----------
drop policy if exists "perfiles_select" on public.perfiles;
create policy "perfiles_select" on public.perfiles
  for select using (id = auth.uid() or public.es_admin());
drop policy if exists "perfiles_update" on public.perfiles;
create policy "perfiles_update" on public.perfiles
  for update using (id = auth.uid() or public.es_admin());
drop policy if exists "perfiles_insert" on public.perfiles;
create policy "perfiles_insert" on public.perfiles
  for insert with check (id = auth.uid());

drop policy if exists "preguntas_select" on public.preguntas_encuesta;
create policy "preguntas_select" on public.preguntas_encuesta
  for select to authenticated using (activa or public.es_admin());
drop policy if exists "preguntas_admin" on public.preguntas_encuesta;
create policy "preguntas_admin" on public.preguntas_encuesta
  for all using (public.es_admin()) with check (public.es_admin());

drop policy if exists "encuestas_select" on public.encuestas;
create policy "encuestas_select" on public.encuestas
  for select using (cliente_id = auth.uid() or public.es_admin());
drop policy if exists "encuestas_insert" on public.encuestas;
create policy "encuestas_insert" on public.encuestas
  for insert with check (cliente_id = auth.uid() or public.es_admin());
drop policy if exists "encuestas_admin" on public.encuestas;
create policy "encuestas_admin" on public.encuestas
  for all using (public.es_admin()) with check (public.es_admin());

drop policy if exists "respuestas_select" on public.respuestas_encuesta;
create policy "respuestas_select" on public.respuestas_encuesta
  for select using (
    exists (select 1 from public.encuestas e
            where e.id = encuesta_id and (e.cliente_id = auth.uid() or public.es_admin()))
  );
drop policy if exists "respuestas_write" on public.respuestas_encuesta;
create policy "respuestas_write" on public.respuestas_encuesta
  for all using (
    exists (select 1 from public.encuestas e
            where e.id = encuesta_id and (e.cliente_id = auth.uid() or public.es_admin()))
  ) with check (
    exists (select 1 from public.encuestas e
            where e.id = encuesta_id and (e.cliente_id = auth.uid() or public.es_admin()))
  );

drop policy if exists "sesiones_todas" on public.sesiones;
create policy "sesiones_todas" on public.sesiones
  for all using (cliente_id = auth.uid() or public.es_admin())
  with check (cliente_id = auth.uid() or public.es_admin());

drop policy if exists "archivos_todas" on public.archivos;
create policy "archivos_todas" on public.archivos
  for all using (cliente_id = auth.uid() or public.es_admin())
  with check (cliente_id = auth.uid() or public.es_admin());

drop policy if exists "citas_todas" on public.citas;
create policy "citas_todas" on public.citas
  for all using (cliente_id = auth.uid() or public.es_admin())
  with check (cliente_id = auth.uid() or public.es_admin());

drop policy if exists "qr_select" on public.qr_accesos;
create policy "qr_select" on public.qr_accesos
  for select using (cliente_id = auth.uid() or public.es_admin());
drop policy if exists "qr_admin_write" on public.qr_accesos;
create policy "qr_admin_write" on public.qr_accesos
  for all using (public.es_admin()) with check (public.es_admin());

drop policy if exists "recordatorios_admin" on public.recordatorios_log;
create policy "recordatorios_admin" on public.recordatorios_log
  for all using (public.es_admin()) with check (public.es_admin());

-- ---------- 4) Storage: bucket + políticas ----------
insert into storage.buckets (id, name, public)
values ('archivos-consultoria', 'archivos-consultoria', false)
on conflict (id) do nothing;

drop policy if exists "storage_select_propios" on storage.objects;
create policy "storage_select_propios" on storage.objects
  for select using (
    bucket_id = 'archivos-consultoria'
    and (auth.uid()::text = (storage.foldername(name))[1] or public.es_admin())
  );
drop policy if exists "storage_insert_propios" on storage.objects;
create policy "storage_insert_propios" on storage.objects
  for insert with check (
    bucket_id = 'archivos-consultoria'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
drop policy if exists "storage_delete_propios" on storage.objects;
create policy "storage_delete_propios" on storage.objects
  for delete using (
    bucket_id = 'archivos-consultoria'
    and (auth.uid()::text = (storage.foldername(name))[1] or public.es_admin())
  );

notify pgrst, 'reload schema';
