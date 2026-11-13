import { supabaseAdmin, supabaseAuth } from '../lib/supabase.js';

// Verifica el JWT de Supabase (Authorization: Bearer <token>) y adjunta req.user.
export async function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;

  if (!token) {
    return res.status(401).json({ error: 'No autenticado.' });
  }

  const { data, error } = await supabaseAuth.auth.getUser(token);
  if (error || !data.user) {
    return res.status(401).json({ error: 'Sesion invalida o expirada.' });
  }

  req.user = data.user;
  next();
}

// Requiere un rol especifico en la tabla perfiles ('admin' | 'cliente').
export function requireRole(rol) {
  return async (req, res, next) => {
    const { data: perfil, error } = await supabaseAdmin
      .from('perfiles')
      .select('rol')
      .eq('id', req.user.id)
      .single();

    if (error || !perfil) {
      return res.status(403).json({ error: 'Perfil no encontrado.' });
    }
    if (perfil.rol !== rol && perfil.rol !== 'admin') {
      return res.status(403).json({ error: 'No tienes permisos para esta accion.' });
    }
    req.rol = perfil.rol;
    next();
  };
}
