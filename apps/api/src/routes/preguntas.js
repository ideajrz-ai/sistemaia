import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth, requireRole } from '../middleware/auth.js';

const router = Router();

// GET /api/preguntas?activas=1 — autenticados (la encuesta las necesita)
router.get('/', requireAuth, async (req, res) => {
  let q = supabaseAdmin
    .from('preguntas_encuesta')
    .select('*')
    .order('orden', { ascending: true });
  if (req.query.activas === '1') q = q.eq('activa', true);
  const { data, error } = await q;
  if (error) return res.status(500).json({ error: error.message });
  res.json({ preguntas: data });
});

// POST /api/preguntas — solo admin
router.post('/', requireAuth, requireRole('admin'), async (req, res) => {
  const { texto, tipo, opciones, obligatoria = true, orden = 0 } = req.body;
  if (!texto || !tipo) {
    return res.status(400).json({ error: 'texto y tipo son obligatorios.' });
  }
  const { data, error } = await supabaseAdmin
    .from('preguntas_encuesta')
    .insert({ texto, tipo, opciones: opciones ?? null, obligatoria, orden })
    .select()
    .single();
  if (error) return res.status(500).json({ error: error.message });
  res.status(201).json({ pregunta: data });
});

// PATCH /api/preguntas/:id — solo admin
router.patch('/:id', requireAuth, requireRole('admin'), async (req, res) => {
  const permitidos = ['texto', 'tipo', 'opciones', 'obligatoria', 'orden', 'activa'];
  const cambios = {};
  for (const k of permitidos) if (req.body[k] !== undefined) cambios[k] = req.body[k];
  if (!Object.keys(cambios).length) {
    return res.status(400).json({ error: 'Sin campos validos.' });
  }
  const { data, error } = await supabaseAdmin
    .from('preguntas_encuesta')
    .update(cambios)
    .eq('id', req.params.id)
    .select()
    .single();
  if (error) return res.status(500).json({ error: error.message });
  res.json({ pregunta: data });
});

// DELETE /api/preguntas/:id — soft delete (activa=false) para no romper respuestas viejas
router.delete('/:id', requireAuth, requireRole('admin'), async (req, res) => {
  const { error } = await supabaseAdmin
    .from('preguntas_encuesta')
    .update({ activa: false })
    .eq('id', req.params.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

export default router;
