# SistemaIA · Consultoría

Sistema de administración para consultoría: diagnóstico de necesidades por encuesta/documentos,
gestión de clientes, sesiones, archivos, citas con recordatorios y QR de acceso.

## Estructura (monorepo para Vercel)

```
SISTEMAIA/
├── apps/
│   ├── web/          # Frontend SvelteKit (adapter-vercel)
│   └── api/          # Backend Node.js + Express (serverless en Vercel)
├── supabase/
│   └── schema.sql    # Tablas, RLS, storage y triggers de Supabase
├── .env.example      # Variables de entorno (copiar a cada app)
└── package.json      # Workspaces de npm
```

## Stack

- **Frontend:** SvelteKit + Svelte 5 + `@supabase/supabase-js`
- **Backend:** Node.js + Express + `@supabase/supabase-js` (service role)
- **BD/Auth/Storage:** Supabase (PostgreSQL + Auth + Storage)
- **Deploy:** Vercel (dos proyectos: `apps/web` y `apps/api`)

## Seguridad implementada

- Contraseñas gestionadas por **Supabase Auth** (hash bcrypt interno, nunca se tocan en el código).
- Backend valida el **JWT** del usuario en cada request (`Authorization: Bearer`).
- **RLS** en todas las tablas: cada cliente solo ve sus datos; el admin ve todo.
- **Rate limiting** global (300 req/15min) y estricto en auth (20 req/15min).
- `helmet`, CORS restringido a `APP_URL`, variables sensibles solo en `.env`.
- Tokens QR se guardan **hasheados**, nunca en plano.

## Configuración local

1. Crea un proyecto en [supabase.com](https://supabase.com).
2. En **SQL Editor**, ejecuta `supabase/schema.sql` completo.
3. Copia `.env.example` → `apps/api/.env` y `apps/web/.env` y rellena las claves
   (Supabase Dashboard → Project Settings → API).
4. Instala dependencias: `npm install`
5. Ejecuta en dos terminales:
   - `npm run dev:api`  → API en http://localhost:3001
   - `npm run dev:web`  → Web en http://localhost:5173

## Convertir tu usuario en admin

Regístrate primero desde `/registro`, luego en SQL Editor:

```sql
update public.perfiles set rol = 'admin' where email = 'tu-correo@ejemplo.com';
```

## Deploy en Vercel

Crea **dos proyectos** en Vercel apuntando al mismo repo:

| Proyecto | Root Directory | Framework |
|---|---|---|
| web     | `apps/web`     | SvelteKit |
| api     | `apps/api`     | Other    |

Variables de entorno a configurar en cada proyecto (ver `.env.example`):

- **web:** `PUBLIC_SUPABASE_URL`, `PUBLIC_SUPABASE_ANON_KEY`, `PUBLIC_API_URL` (URL del proyecto api)
- **api:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `APP_URL` (URL del proyecto web), `QR_SECRET`

## Etapas del proyecto

- [x] **Etapa 1:** Monorepo, autenticación (registro/login), roles admin/cliente,
      perfiles editables, panel admin, esquema BD completo.
- [x] **Etapa 2:** CRUD de preguntas de encuesta (admin en `/admin/preguntas`) y
      encuesta del cliente en `/encuesta` con validación de obligatorias.
- [x] **Etapa 3:** Motor de diagnóstico por reglas (`src/lib/diagnostico.js`) que
      genera diagnóstico + recomendaciones al enviar la encuesta; carga de
      documentos/imágenes a Storage desde `/archivos`.
- [x] **Etapa 4:** Sesiones por cliente (`/sesiones`) con estados y archivos
      vinculados por sesión.
- [x] **Etapa 5:** Citas con recordatorio configurable (`/citas`). El envío real
      requiere `SMTP_*` y/o `WHATSAPP_*` en `.env`; sin credenciales se registran
      como "simulado" en `recordatorios_log`. Disparo: `POST /api/admin/recordatorios/procesar`
      (admin o cron con header `x-cron-secret: $CRON_SECRET`).
- [x] **Etapa 6:** QR de acceso diario (`/qr`) — token hasheado, válido solo la
      fecha indicada y un solo uso. Recepción valida en `/acceso?token=…`
      (endpoint público `GET /api/qr/validar`).
- [x] **Extra:** el admin decide qué módulos ve cada cliente
      (`modulos_visibles` en `/admin/clientes`); el nav y dashboard se adaptan.

## Notas

- **Diagnóstico:** actualmente es un motor de reglas determinista. Para usar un
  LLM real, reemplaza `generarDiagnostico()` en `apps/api/src/lib/diagnostico.js`
  por una llamada a la API de IA que prefieras (solo requiere `ANTHROPIC_API_KEY`
  u otra en `.env`).
- **WhatsApp:** configura `WHATSAPP_API_URL` + `WHATSAPP_TOKEN` (360dialog o Meta
  Cloud API) para envío real; si no, los recordatorios quedan registrados como
  simulados.
- **Emails:** configura `SMTP_*` (Resend, SendGrid, Gmail, etc.).
