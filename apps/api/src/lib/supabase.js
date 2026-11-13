import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL;
const anonKey = process.env.SUPABASE_ANON_KEY;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

const faltantes = [
  ['SUPABASE_URL', url],
  ['SUPABASE_ANON_KEY', anonKey],
  ['SUPABASE_SERVICE_ROLE_KEY', serviceKey],
].filter(([, v]) => !v).map(([k]) => k);

if (faltantes.length) {
  throw new Error(
    `Faltan variables de entorno en apps/api/.env: ${faltantes.join(', ')}. ` +
    'Copia .env.example y configurala.'
  );
}

// Cliente con service_role: by-pass RLS, SOLO para operaciones de confianza en el backend.
export const supabaseAdmin = createClient(url, serviceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// Cliente anon para validar JWTs de usuarios (respeta RLS del lado del usuario)
export const supabaseAuth = createClient(url, anonKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
