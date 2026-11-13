import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { procesarRecordatorios } from '../lib/recordatorios.js';

const router = Router();

// PATCH /api/admin/clientes/:id — el admin decide que modulos ve el cliente
// y puede editar datos generales del expediente.
router.patch('/clientes/:id', requireAuth, requireRole('admin'), async (req, res) => {
  const permitidos = ['nombre', 'telefono', 'direccion', 'necesidad', 'modulos_visibles'];
  const cambios = {};
  for (const k of permitidos) if (req.body[k] !== undefined) cambios[k] = req.body[k];

  if (cambios.modulos_visibles !== undefined) {
    if (!Array.isArray(cambios.modulos_visibles)) {
      return res.status(400).json({ error: 'modulos_visibles debe ser un arreglo.' });
    }
  }
  if (!Object.keys(cambios).length) {
    return res.status(400).json({ error: 'Sin campos validos.' });
  }

  const { data, error } = await supabaseAdmin
    .from('perfiles')
    .update(cambios)
    .eq('id', req.params.id)
    .select()
    .single();
  if (error) return res.status(500).json({ error: error.message });
  res.json({ perfil: data });
});

// GET /api/admin/clientes/:id — expediente completo del cliente
router.get('/clientes/:id', requireAuth, requireRole('admin'), async (req, res) => {
  const { data: perfil, error } = await supabaseAdmin
    .from('perfiles').select('*').eq('id', req.params.id).single();
  if (error) return res.status(404).json({ error: 'Cliente no encontrado.' });

  const [encuestas, sesiones, citas, archivos] = await Promise.all([
    supabaseAdmin.from('encuestas').select('*').eq('cliente_id', req.params.id).order('created_at', { ascending: false }),
    supabaseAdmin.from('sesiones').select('*').eq('cliente_id', req.params.id).order('fecha', { ascending: false }),
    supabaseAdmin.from('citas').select('*').eq('cliente_id', req.params.id).order('fecha_inicio', { ascending: true }),
    supabaseAdmin.from('archivos').select('id, nombre, tipo_mime, tamano_bytes, created_at').eq('cliente_id', req.params.id),
  ]);

  res.json({
    perfil,
    encuestas: encuestas.data ?? [],
    sesiones: sesiones.data ?? [],
    citas: citas.data ?? [],
    archivos: archivos.data ?? [],
  });
});

// POST /api/admin/recordatorios/procesar — dispara el envio de recordatorios
// (admin manual, o cron externo con header x-cron-secret)
router.post('/recordatorios/procesar', async (req, res) => {
  const esAdmin = req.headers.authorization
    ? await (async () => {
        try {
          const token = req.headers.authorization.replace('Bearer ', '');
          const { data } = await supabaseAdmin.auth.getUser(token);
          if (!data.user) return false;
          const { data: p } = await supabaseAdmin
            .from('perfiles').select('rol').eq('id', data.user.id).single();
          return p?.rol === 'admin';
        } catch { return false; }
      })()
    : false;
  const cronOk = process.env.CRON_SECRET && req.headers['x-cron-secret'] === process.env.CRON_SECRET;

  if (!esAdmin && !cronOk) {
    return res.status(401).json({ error: 'No autorizado.' });
  }

  try {
    const resultado = await procesarRecordatorios();
    res.json(resultado);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

export default router;
