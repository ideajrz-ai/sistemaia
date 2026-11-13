# SistemaIA · Consultoría

Sistema de administración para consultoría: diagnóstico de necesidades por encuesta/documentos,
gestión de clientes, sesiones, archivos, citas con recordatorios y QR de acceso.

## Estructura

```
SISTEMAIA/
├── src/              # Código fuente SvelteKit
├── apps/api/         # Backend Express
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
5. Ejecuta `npx vercel@latest dev --local` para iniciar web y API juntas (ver configuración de Vercel abajo).

## Convertir tu usuario en admin

Regístrate primero desde `/registro`, luego en SQL Editor:

```sql
update public.perfiles set rol = 'admin' where email = 'tu-correo@ejemplo.com';
```

## Deploy en Vercel con varios servicios

Importa este repositorio como **un solo proyecto** con Root Directory `.`. La configuración de `vercel.json` define dos servicios:

| Servicio | Raíz | Framework | Rutas públicas |
|---|---|---|---|
| `app` | `.` | SvelteKit | `/` y las rutas que no empiecen con `/api` |
| `api` | `apps/api` | Express (`src/app.js`) | `/api` y `/api/*` |

Las rutas conservan el prefijo `/api` al llegar a Express. El catch-all de `app` va al final; un 404 de la API no se convierte en una página HTML de SvelteKit.

Actualmente las llamadas a la API salen del navegador (y de la APK), usando `/api/*` en el mismo dominio. No hay llamadas HTTP entre funciones de los dos servicios y por eso no se declaran bindings privados. `WEB_URL` no es un binding: los QR necesitan una URL pública que pueda abrir el navegador. Si se introduce un gateway o llamadas desde funciones de SvelteKit, el binding deberá declararse en `app` y leerse mediante `$env/dynamic/private` dentro de una función, nunca en código del navegador, middleware o durante el build.

Configura en el proyecto Vercel:

- Build de la web: `PUBLIC_SUPABASE_URL`, `PUBLIC_SUPABASE_ANON_KEY`.
- Runtime de la API: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.
- `APP_URL`: origen HTTPS público de la web para los QR y CORS, por ejemplo `https://tu-dominio.example`. Si no se configura, se utiliza `VERCEL_URL` para el despliegue actual. No pongas `localhost` en Vercel.
- SMTP, WhatsApp y cron: las variables opcionales descritas en `.env.example`.

Elimina overrides anteriores de Build Command, Install Command y Output Directory en el dashboard que pertenecieran al despliegue de un solo servicio. Los ajustes de build ahora pertenecen al servicio correspondiente. No configures `PUBLIC_API_URL` ni `WEB_URL`; la web utiliza el origen actual y los QR utilizan el origen público indicado arriba.

Para probar ambos servicios con el enrutamiento de Vercel:

```sh
npm install
npx vercel@latest dev --local
```

Prueba `/`, `/login`, `/api/health` y `/api/me` (sin sesión debe responder 401 JSON). El comando ejecuta los servicios sin publicar un deployment. Para desarrollo independiente, ejecuta `npm run dev:api` y `npm run dev` en terminales separadas; Vite redirige `/api/*` al puerto 3001, configurable con `API_DEV_URL` solamente en desarrollo.

Ejecuta `npm run build` y `npm test --workspace=apps/api` antes de desplegar. Los nombres, exposición pública y ausencia de bindings de esta propuesta están pendientes de confirmación.

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
