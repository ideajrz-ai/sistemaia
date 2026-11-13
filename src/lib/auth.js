import { supabase } from './supabase.js';
import { goto } from '$app/navigation';

// In Vercel services mode, API routes are served under /api/* via rewrites
// In local development, use PUBLIC_API_URL from .env
const API_URL = import.meta.env.PUBLIC_API_URL || '';

// Llama al backend Node con el JWT de Supabase del usuario actual.
export async function apiFetch(path, options = {}) {
  const { data: { session } } = await supabase.auth.getSession();
  // Use absolute URL in dev, relative path in production (services mode)
  const url = API_URL ? `${API_URL}${path}` : path;
  const res = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(session ? { Authorization: `Bearer ${session.access_token}` } : {}),
      ...(options.headers || {}),
    },
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(body.error || `Error ${res.status}`);
  return body;
}

// Devuelve la sesion actual o redirige a /login.
export async function requireSession() {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) {
    goto('/login');
    return null;
  }
  return session;
}

// Devuelve el perfil del usuario actual (rol admin/cliente, datos generales).
export async function getMyProfile() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;
  const { data } = await supabase
    .from('perfiles')
    .select('*')
    .eq('id', user.id)
    .single();
  return data;
}
