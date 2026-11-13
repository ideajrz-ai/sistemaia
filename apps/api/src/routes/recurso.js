import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth, requireRole } from '../middleware/auth.js';

const router = Router();

// CRUD generico para "recurso del cliente": sesiones, citas, archivos
// tabla: nombre real en BD; scope: 'cliente_id'
export function crudRecurso(tabla, { adminPuedeElegirCliente = false } = {}) {
  const r = Router();

  r.get('/', requireAuth, async (req, res) => {
    const esAdmin = await checkAdmin(req.user.id);
    let q = supabaseAdmin.from(tabla).select('*').order('created_at', { ascending: false });
    if (!esAdmin || req.query.mios === '1') {
      q = q.eq('cliente_id', req.user.id);
    } else if (req.query.cliente_id) {
      q = q.eq('cliente_id', req.query.cliente_id);
    }
    const { data, error } = await q;
    if (error) return res.status(500).json({ error: error.message });
    res.json({ items: data });
  });

  r.post('/', requireAuth, async (req, res) => {
    const esAdmin = await checkAdmin(req.user.id);
    const clienteId = esAdmin && adminPuedeElegirCliente && req.body.cliente_id
      ? req.body.cliente_id
      : req.user.id;
    const { data, error } = await supabaseAdmin
      .from(tabla)
      .insert({ ...req.body, cliente_id: clienteId })
      .select()
      .single();
    if (error) return res.status(500).json({ error: error.message });
    res.status(201).json({ item: data });
  });

  r.patch('/:id', requireAuth, async (req, res) => {
    const { data: existente, error: errFind } = await supabaseAdmin
      .from(tabla).select('cliente_id').eq('id', req.params.id).single();
    if (errFind) return res.status(404).json({ error: 'No encontrado.' });
    const esAdmin = await checkAdmin(req.user.id);
    if (existente.cliente_id !== req.user.id && !esAdmin) {
      return res.status(403).json({ error: 'Sin permiso.' });
    }
    const { cliente_id, id, ...cambios } = req.body;
    const { data, error } = await supabaseAdmin
      .from(tabla).update(cambios).eq('id', req.params.id).select().single();
    if (error) return res.status(500).json({ error: error.message });
    res.json({ item: data });
  });

  r.delete('/:id', requireAuth, async (req, res) => {
    const { data: existente, error: errFind } = await supabaseAdmin
      .from(tabla).select('cliente_id').eq('id', req.params.id).single();
    if (errFind) return res.status(404).json({ error: 'No encontrado.' });
    const esAdmin = await checkAdmin(req.user.id);
    if (existente.cliente_id !== req.user.id && !esAdmin) {
      return res.status(403).json({ error: 'Sin permiso.' });
    }
    const { error } = await supabaseAdmin.from(tabla).delete().eq('id', req.params.id);
    if (error) return res.status(500).json({ error: error.message });
    res.json({ ok: true });
  });

  return r;
}

async function checkAdmin(userId) {
  const { data } = await supabaseAdmin
    .from('perfiles').select('rol').eq('id', userId).single();
  return data?.rol === 'admin';
}

export { requireRole };
