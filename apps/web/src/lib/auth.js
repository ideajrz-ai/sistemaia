import { supabase } from './supabase.js';
import { goto } from '$app/navigation';

export const API_URL = import.meta.env.PUBLIC_API_URL || 'http://localhost:3001';

// Llama al backend Node con el JWT de Supabase del usuario actual.
export async function apiFetch(path, options = {}) {
  const { data: { session } } = await supabase.auth.getSession();
  const res = await fetch(`${API_URL}${path}`, {
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
