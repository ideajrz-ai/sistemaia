-- ============================================================
-- SISTEMAIA · Esquema de base de datos (Supabase / PostgreSQL)
-- Ejecutar en: Supabase Dashboard > SQL Editor > New query
-- ============================================================

-- ---------- Extensiones ----------
create extension if not exists "pgcrypto";

-- ---------- Tabla de perfiles (datos generales del cliente/usuario) ----------
create table public.perfiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  nombre      text,
  email       text,
  telefono    text,
  direccion   text,
  necesidad   text,                 -- necesidad/servicio que solicita
  rol         text not null default 'cliente' check (rol in ('admin', 'cliente')),
  -- modulos del portal que el admin decide mostrar al cliente
  modulos_visibles jsonb not null default
    '["panel","encuesta","sesiones","archivos","citas","qr"]'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Trigger: crear perfil automaticamente al registrarse en auth.users
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.perfiles (id, nombre, email, telefono, direccion, necesidad)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nombre', ''),
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

-- Impedir que un usuario cambie su propio rol
create or replace function public.proteger_rol()
returns trigger
language plpgsql
as $$
begin
  if new.rol is distinct from old.rol
     and coalesce(current_setting('request.jwt.claims', true)::json->>'role', '') <> 'service_role' then
    -- solo el service_role (backend admin) puede cambiar roles
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

-- ---------- Preguntas de la encuesta (editables por el admin) ----------
create table public.preguntas_encuesta (
  id          uuid primary key default gen_random_uuid(),
  texto       text not null,
  tipo        text not null check (tipo in ('si_no', 'opcion_unica', 'opcion_multiple', 'texto', 'numero', 'escala')),
  opciones    jsonb,                  -- arreglo de opciones cuando aplica
  obligatoria boolean not null default true,
  orden       int not null default 0,
  activa      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- ---------- Encuestas respondidas (diagnostico por cliente) ----------
create table public.encuestas (
  id               uuid primary key default gen_random_uuid(),
  cliente_id       uuid not null references public.perfiles(id) on delete cascade,
  estado           text not null default 'borrador' check (estado in ('borrador', 'completada')),
  diagnostico      text,              -- texto generado del analisis
  recomendaciones  text,              -- recomendaciones para el cliente
  created_at       timestamptz not null default now(),
  completada_at    timestamptz
);

create table public.respuestas_encuesta (
  id           uuid primary key default gen_random_uuid(),
  encuesta_id  uuid not null references public.encuestas(id) on delete cascade,
  pregunta_id  uuid not null references public.preguntas_encuesta(id),
  respuesta    jsonb not null,        -- texto, numero, arreglo u objeto segun tipo
  created_at   timestamptz not null default now(),
  unique (encuesta_id, pregunta_id)
);

-- ---------- Sesiones de consultoria ----------
create table public.sesiones (
  id           uuid primary key default gen_random_uuid(),
  cliente_id   uuid not null references public.perfiles(id) on delete cascade,
  titulo       text not null,
  descripcion  text,
  fecha        date not null,
  hora_inicio  time,
  duracion_min int default 60,
  estado       text not null default 'programada' check (estado in ('programada', 'realizada', 'cancelada')),
  notas        text,
  created_at   timestamptz not null default now()
);

-- ---------- Archivos e imagenes por sesion/cliente ----------
create table public.archivos (
  id            uuid primary key default gen_random_uuid(),
  cliente_id    uuid not null references public.perfiles(id) on delete cascade,
  sesion_id     uuid references public.sesiones(id) on delete set null,
  nombre        text not null,
  tipo_mime     text,
  tamano_bytes  bigint,
  ruta_storage  text not null,        -- ruta dentro del bucket
  subido_por    uuid references public.perfiles(id),
  created_at    timestamptz not null default now()
);

-- ---------- Citas con recordatorios ----------
create table public.citas (
  id                  uuid primary key default gen_random_uuid(),
  cliente_id          uuid not null references public.perfiles(id) on delete cascade,
  titulo              text not null,
  fecha_inicio        timestamptz not null,
  fecha_fin           timestamptz,
  notas               text,
  recordatorio_min    int not null default 1440,  -- minutos antes (1440 = 24h)
  recordatorio_enviado boolean not null default false,
  created_at          timestamptz not null default now()
);

-- ---------- Log de recordatorios enviados (correo / WhatsApp) ----------
create table public.recordatorios_log (
  id          uuid primary key default gen_random_uuid(),
  cita_id     uuid references public.citas(id) on delete cascade,
  cliente_id  uuid references public.perfiles(id) on delete cascade,
  canal       text not null check (canal in ('email', 'whatsapp', 'simulado')),
  destino     text,                  -- correo o telefono destino
  estado      text not null default 'enviado' check (estado in ('enviado', 'fallido', 'simulado')),
  detalle     text,
  created_at  timestamptz not null default now()
);

-- ---------- QR de acceso de un solo dia ----------
create table public.qr_accesos (
  id            uuid primary key default gen_random_uuid(),
  cliente_id    uuid not null references public.perfiles(id) on delete cascade,
  fecha_valida  date not null,          -- solo valido ese dia
  token_hash    text not null,          -- hash del token (nunca el token plano)
  usado         boolean not null default false,
  expira_at     timestamptz not null default (now() + interval '24 hours'),
  created_at    timestamptz not null default now()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table public.perfiles          enable row level security;
alter table public.preguntas_encuesta enable row level security;
alter table public.encuestas         enable row level security;
alter table public.respuestas_encuesta enable row level security;
alter table public.sesiones          enable row level security;
alter table public.archivos          enable row level security;
alter table public.citas             enable row level security;
alter table public.qr_accesos        enable row level security;
alter table public.recordatorios_log enable row level security;

-- Helper: ¿el usuario es admin?
create or replace function public.es_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.perfiles
    where id = auth.uid() and rol = 'admin'
  );
$$;

-- perfiles: cada quien ve/edita lo suyo; admin ve todo
create policy "perfiles_select" on public.perfiles
  for select using (id = auth.uid() or public.es_admin());
create policy "perfiles_update" on public.perfiles
  for update using (id = auth.uid() or public.es_admin());
create policy "perfiles_insert" on public.perfiles
  for insert with check (id = auth.uid());

-- preguntas: lectura publica para autenticados; escritura solo admin
create policy "preguntas_select" on public.preguntas_encuesta
  for select to authenticated using (activa or public.es_admin());
create policy "preguntas_admin" on public.preguntas_encuesta
  for all using (public.es_admin()) with check (public.es_admin());

-- encuestas y respuestas: cliente solo las suyas; admin todo
create policy "encuestas_select" on public.encuestas
  for select using (cliente_id = auth.uid() or public.es_admin());
create policy "encuestas_insert" on public.encuestas
  for insert with check (cliente_id = auth.uid() or public.es_admin());
create policy "encuestas_admin" on public.encuestas
  for all using (public.es_admin()) with check (public.es_admin());

create policy "respuestas_select" on public.respuestas_encuesta
  for select using (
    exists (select 1 from public.encuestas e
            where e.id = encuesta_id and (e.cliente_id = auth.uid() or public.es_admin()))
  );
create policy "respuestas_write" on public.respuestas_encuesta
  for all using (
    exists (select 1 from public.encuestas e
            where e.id = encuesta_id and (e.cliente_id = auth.uid() or public.es_admin()))
  ) with check (
    exists (select 1 from public.encuestas e
            where e.id = encuesta_id and (e.cliente_id = auth.uid() or public.es_admin()))
  );

-- sesiones, archivos, citas, qr: propietario o admin
create policy "sesiones_todas" on public.sesiones
  for all using (cliente_id = auth.uid() or public.es_admin())
  with check (cliente_id = auth.uid() or public.es_admin());

create policy "archivos_todas" on public.archivos
  for all using (cliente_id = auth.uid() or public.es_admin())
  with check (cliente_id = auth.uid() or public.es_admin());

create policy "citas_todas" on public.citas
  for all using (cliente_id = auth.uid() or public.es_admin())
  with check (cliente_id = auth.uid() or public.es_admin());

create policy "qr_select" on public.qr_accesos
  for select using (cliente_id = auth.uid() or public.es_admin());
create policy "qr_admin_write" on public.qr_accesos
  for all using (public.es_admin()) with check (public.es_admin());

-- log de recordatorios: solo admin (el backend usa service_role)
create policy "recordatorios_admin" on public.recordatorios_log
  for all using (public.es_admin()) with check (public.es_admin());

-- ============================================================
-- STORAGE: bucket privado para archivos de consultoria
-- ============================================================
insert into storage.buckets (id, name, public)
values ('archivos-consultoria', 'archivos-consultoria', false)
on conflict (id) do nothing;

-- Cada cliente sube/lee solo dentro de su carpeta {cliente_id}/
create policy "storage_select_propios" on storage.objects
  for select using (
    bucket_id = 'archivos-consultoria'
    and (auth.uid()::text = (storage.foldername(name))[1] or public.es_admin())
  );
create policy "storage_insert_propios" on storage.objects
  for insert with check (
    bucket_id = 'archivos-consultoria'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "storage_delete_propios" on storage.objects
  for delete using (
    bucket_id = 'archivos-consultoria'
    and (auth.uid()::text = (storage.foldername(name))[1] or public.es_admin())
  );

-- ============================================================
-- PROMOVER ADMIN (ejecutar manualmente una sola vez)
-- Cambia 'tu-correo@ejemplo.com' por tu correo de administrador:
-- ============================================================
-- update public.perfiles set rol = 'admin'
-- where email = 'tu-correo@ejemplo.com';
