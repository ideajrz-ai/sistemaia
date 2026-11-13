import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { generarDiagnostico } from '../lib/diagnostico.js';

const router = Router();

// POST /api/encuestas — el cliente envia sus respuestas y se genera el diagnostico
router.post('/', requireAuth, async (req, res) => {
  const { respuestas = [] } = req.body;
  if (!Array.isArray(respuestas) || !respuestas.length) {
    return res.status(400).json({ error: 'Debes enviar al menos una respuesta.' });
  }

  // Verificar que todas las preguntas existan y esten activas
  const ids = [...new Set(respuestas.map((r) => r.pregunta_id))];
  const { data: preguntas, error: errP } = await supabaseAdmin
    .from('preguntas_encuesta')
    .select('*')
    .in('id', ids)
    .eq('activa', true);
  if (errP) return res.status(500).json({ error: errP.message });
  if (preguntas.length !== ids.length) {
    return res.status(400).json({ error: 'Hay preguntas invalidas o inactivas.' });
  }
  // Validar obligatorias respondidas
  const faltantes = preguntas.filter(
    (p) => p.obligatoria && !respuestas.some((r) => r.pregunta_id === p.id && r.respuesta !== null && r.respuesta !== '')
  );
  if (faltantes.length) {
    return res.status(400).json({ error: `Faltan respuestas obligatorias (${faltantes.length}).` });
  }

  // Crear encuesta completada
  const { data: encuesta, error: errE } = await supabaseAdmin
    .from('encuestas')
    .insert({ cliente_id: req.user.id, estado: 'completada', completada_at: new Date().toISOString() })
    .select()
    .single();
  if (errE) return res.status(500).json({ error: errE.message });

  // Guardar respuestas
  const filas = respuestas.map((r) => ({
    encuesta_id: encuesta.id,
    pregunta_id: r.pregunta_id,
    respuesta: r.respuesta,
  }));
  const { error: errR } = await supabaseAdmin.from('respuestas_encuesta').insert(filas);
  if (errR) {
    await supabaseAdmin.from('encuestas').delete().eq('id', encuesta.id);
    return res.status(500).json({ error: errR.message });
  }

  // Generar diagnostico y guardarlo
  const { diagnostico, recomendaciones } = generarDiagnostico(respuestas, preguntas);
  const { data: final, error: errD } = await supabaseAdmin
    .from('encuestas')
    .update({ diagnostico, recomendaciones })
    .eq('id', encuesta.id)
    .select()
    .single();
  if (errD) return res.status(500).json({ error: errD.message });

  res.status(201).json({ encuesta: final });
});

// GET /api/encuestas — mias (cliente) o todas (admin con ?todos=1)
router.get('/', requireAuth, async (req, res) => {
  const esAdmin = req.rol === 'admin' || (await esAdminReq(req));
  let q = supabaseAdmin.from('encuestas').select('*').order('created_at', { ascending: false });
  if (!(esAdmin && req.query.todos === '1')) {
    q = q.eq('cliente_id', req.user.id);
  }
  const { data, error } = await q;
  if (error) return res.status(500).json({ error: error.message });
  res.json({ encuestas: data });
});

// GET /api/encuestas/:id — con respuestas y texto de cada pregunta
router.get('/:id', requireAuth, async (req, res) => {
  const { data: encuesta, error } = await supabaseAdmin
    .from('encuestas')
    .select('*, perfiles!encuestas_cliente_id_fkey(nombre, email)')
    .eq('id', req.params.id)
    .single();
  if (error) return res.status(404).json({ error: 'Encuesta no encontrada.' });

  const esAdmin = await esAdminReq(req);
  if (encuesta.cliente_id !== req.user.id && !esAdmin) {
    return res.status(403).json({ error: 'Sin permiso.' });
  }

  const { data: respuestas } = await supabaseAdmin
    .from('respuestas_encuesta')
    .select('*, preguntas_encuesta(texto, tipo, opciones)')
    .eq('encuesta_id', encuesta.id);

  res.json({ encuesta, respuestas: respuestas ?? [] });
});

async function esAdminReq(req) {
  const { data } = await supabaseAdmin
    .from('perfiles')
    .select('rol')
    .eq('id', req.user.id)
    .single();
  return data?.rol === 'admin';
}

export default router;
