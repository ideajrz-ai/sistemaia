# SistemaIA · Consultoría

Sistema de administración para consultoría: diagnóstico de necesidades por encuesta/documentos,
gestión de clientes, sesiones, archivos, citas con recordatorios y QR de acceso.

## Estructura

```
SISTEMAIA/
├── src/              # Código fuente SvelteKit
├── static/           # Archivos estáticos
├── supabase/         # Schema SQL de Supabase
├── appmovil/         # Aplicación Android (Flutter)
├── .env.example      # Variables de entorno
└── package.json      # Dependencias del proyecto
```

## Stack

- **Frontend:** SvelteKit + Svelte 5 + `@supabase/supabase-js`
- **BD/Auth/Storage:** Supabase (PostgreSQL + Auth + Storage)
- **Deploy:** Vercel

## Seguridad implementada

- Contraseñas gestionadas por **Supabase Auth** (hash bcrypt interno).
- **RLS** en todas las tablas: cada cliente solo ve sus datos; el admin ve todo.
- Tokens QR se guardan **hasheados**, nunca en plano.

## Configuración local

1. Crea un proyecto en [supabase.com](https://supabase.com).
2. En **SQL Editor**, ejecuta `supabase/schema.sql` completo.
3. Copia `.env.example` → `.env` y rellena las claves
   (Supabase Dashboard → Project Settings → API).
4. Instala dependencias: `npm install`
5. Ejecuta: `npm run dev` → Web en http://localhost:5173

## Convertir tu usuario en admin

Regístrate primero desde `/registro`, luego en SQL Editor:

```sql
update public.perfiles set rol = 'admin' where email = 'tu-correo@ejemplo.com';
```

## Deploy en Vercel

Conecta este repositorio a Vercel. El framework se detectará automáticamente como SvelteKit.

Variables de entorno a configurar en Vercel (ver `.env.example`):

- `PUBLIC_SUPABASE_URL`
- `PUBLIC_SUPABASE_ANON_KEY`

## Etapas del proyecto

- [x] **Etapa 1:** Autenticación (registro/login), roles admin/cliente,
      perfiles editables, panel admin, esquema BD completo.
- [x] **Etapa 2:** CRUD de preguntas de encuesta (admin en `/admin/preguntas`) y
      encuesta del cliente en `/encuesta` con validación de obligatorias.
- [x] **Etapa 3:** Motor de diagnóstico por reglas que
      genera diagnóstico + recomendaciones al enviar la encuesta; carga de
      documentos/imágenes a Storage desde `/archivos`.
- [x] **Etapa 4:** Sesiones por cliente (`/sesiones`) con estados y archivos
      vinculados por sesión.
- [x] **Etapa 5:** Citas con recordatorio configurable (`/citas`).
- [x] **Etapa 6:** QR de acceso diario (`/qr`) — token hasheado, válido solo la
      fecha indicada y un solo uso.
- [x] **Extra:** el admin decide qué módulos ve cada cliente
      (`modulos_visibles` en `/admin/clientes`); el nav y dashboard se adaptan.

## Aplicación Android

La app Flutter está en `appmovil/`. Incluye acceso con Supabase y módulos conectados a esta API. Consulta [configuración, compilación y firma de la APK](appmovil/README.md).
