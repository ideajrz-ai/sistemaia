import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();
const BUCKET = 'archivos-consultoria';

async function checkAdmin(userId) {
  const { data } = await supabaseAdmin
    .from('perfiles').select('rol').eq('id', userId).single();
  return data?.rol === 'admin';
}

// GET /api/archivos — mios, o de un cliente (admin)
router.get('/', requireAuth, async (req, res) => {
  const esAdmin = await checkAdmin(req.user.id);
  let q = supabaseAdmin
    .from('archivos')
    .select('*, sesiones(titulo)')
    .order('created_at', { ascending: false });
  if (!esAdmin || req.query.mios === '1') {
    q = q.eq('cliente_id', req.user.id);
  } else if (req.query.cliente_id) {
    q = q.eq('cliente_id', req.query.cliente_id);
  }
  const { data, error } = await q;
  if (error) return res.status(500).json({ error: error.message });
  res.json({ archivos: data });
});

// POST /api/archivos — registra metadata tras subir el archivo a Storage
// El archivo ya debe estar subido a {cliente_id}/{uuid}-{nombre} en el bucket.
router.post('/', requireAuth, async (req, res) => {
  const { nombre, tipo_mime, tamano_bytes, ruta_storage, sesion_id } = req.body;
  if (!nombre || !ruta_storage) {
    return res.status(400).json({ error: 'nombre y ruta_storage son obligatorios.' });
  }
  const esAdmin = await checkAdmin(req.user.id);
  const clienteId = esAdmin && req.body.cliente_id ? req.body.cliente_id : req.user.id;

  // Seguridad: la ruta debe empezar con la carpeta del cliente dueño
  if (!ruta_storage.startsWith(`${clienteId}/`)) {
    return res.status(400).json({ error: 'ruta_storage invalida para este cliente.' });
  }

  const { data, error } = await supabaseAdmin
    .from('archivos')
    .insert({
      cliente_id: clienteId,
      sesion_id: sesion_id || null,
      nombre, tipo_mime, tamano_bytes,
      ruta_storage, subido_por: req.user.id,
    })
    .select()
    .single();
  if (error) return res.status(500).json({ error: error.message });
  res.status(201).json({ archivo: data });
});

// GET /api/archivos/:id/url — URL firmada temporal para descargar
router.get('/:id/url', requireAuth, async (req, res) => {
  const { data: archivo, error } = await supabaseAdmin
    .from('archivos').select('*').eq('id', req.params.id).single();
  if (error) return res.status(404).json({ error: 'Archivo no encontrado.' });
  const esAdmin = await checkAdmin(req.user.id);
  if (archivo.cliente_id !== req.user.id && !esAdmin) {
    return res.status(403).json({ error: 'Sin permiso.' });
  }
  const { data: signed, error: errS } = await supabaseAdmin.storage
    .from(BUCKET)
    .createSignedUrl(archivo.ruta_storage, 300); // 5 min
  if (errS) return res.status(500).json({ error: errS.message });
  res.json({ url: signed.signedUrl });
});

// DELETE /api/archivos/:id — borra metadata y objeto de storage
router.delete('/:id', requireAuth, async (req, res) => {
  const { data: archivo, error } = await supabaseAdmin
    .from('archivos').select('*').eq('id', req.params.id).single();
  if (error) return res.status(404).json({ error: 'Archivo no encontrado.' });
  const esAdmin = await checkAdmin(req.user.id);
  if (archivo.cliente_id !== req.user.id && !esAdmin) {
    return res.status(403).json({ error: 'Sin permiso.' });
  }
  await supabaseAdmin.storage.from(BUCKET).remove([archivo.ruta_storage]);
  const { error: errD } = await supabaseAdmin.from('archivos').delete().eq('id', archivo.id);
  if (errD) return res.status(500).json({ error: errD.message });
  res.json({ ok: true });
});

export default router;
