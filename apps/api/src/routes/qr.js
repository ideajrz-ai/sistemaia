import { Router } from 'express';
import crypto from 'node:crypto';
import QRCode from 'qrcode';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth, requireRole } from '../middleware/auth.js';

const router = Router();
// In Vercel services mode, WEB_URL is injected via binding to the web service
// In local development, use APP_URL from .env
const WEB_URL = process.env.WEB_URL || process.env.APP_URL || 'http://localhost:5173';

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

async function checkAdmin(userId) {
  const { data } = await supabaseAdmin
    .from('perfiles').select('rol').eq('id', userId).single();
  return data?.rol === 'admin';
}

// POST /api/qr — genera QR de acceso
// Body: { fecha?: 'YYYY-MM-DD', cliente_id? (solo admin) }
// Por defecto: hoy. El cliente solo puede generar el suyo.
router.post('/', requireAuth, async (req, res) => {
  const esAdmin = await checkAdmin(req.user.id);
  const clienteId = esAdmin && req.body.cliente_id ? req.body.cliente_id : req.user.id;
  const fecha = req.body.fecha || new Date().toISOString().slice(0, 10);

  if (!/^\d{4}-\d{2}-\d{2}$/.test(fecha)) {
    return res.status(400).json({ error: 'fecha invalida (YYYY-MM-DD).' });
  }

  const token = crypto.randomBytes(32).toString('hex');
  const { data, error } = await supabaseAdmin
    .from('qr_accesos')
    .insert({
      cliente_id: clienteId,
      fecha_valida: fecha,
      token_hash: hashToken(token),
      expira_at: new Date(`${fecha}T23:59:59`).toISOString(),
    })
    .select()
    .single();
  if (error) return res.status(500).json({ error: error.message });

  const url = `${WEB_URL}/acceso?token=${token}`;
  const qr = await QRCode.toDataURL(url, { margin: 1, width: 320 });
  res.status(201).json({
    qr_id: data.id,
    fecha_valida: fecha,
    qr,
    // el token plano solo se devuelve una vez, para mostrar el QR
    aviso: 'Muestra este QR en recepcion el dia indicado.',
  });
});

// GET /api/qr/mios — historial de QR generados (propios o de un cliente si admin)
router.get('/mios', requireAuth, async (req, res) => {
  const esAdmin = await checkAdmin(req.user.id);
  let q = supabaseAdmin
    .from('qr_accesos')
    .select('id, fecha_valida, usado, expira_at, created_at')
    .order('created_at', { ascending: false })
    .limit(30);
  if (!esAdmin || req.query.mios === '1') {
    q = q.eq('cliente_id', req.user.id);
  } else if (req.query.cliente_id) {
    q = q.eq('cliente_id', req.query.cliente_id);
  }
  const { data, error } = await q;
  if (error) return res.status(500).json({ error: error.message });
  res.json({ qr: data });
});

// GET /api/qr/validar?token=... — PUBLICO, lo usa la pagina /acceso en recepcion
router.get('/validar', async (req, res) => {
  const { token } = req.query;
  if (!token || typeof token !== 'string') {
    return res.status(400).json({ valido: false, motivo: 'Token requerido.' });
  }

  const { data: qr, error } = await supabaseAdmin
    .from('qr_accesos')
    .select('*, perfiles!qr_accesos_cliente_id_fkey(nombre)')
    .eq('token_hash', hashToken(token))
    .single();

  if (error || !qr) {
    return res.json({ valido: false, motivo: 'QR no reconocido.' });
  }
  const hoy = new Date().toISOString().slice(0, 10);
  if (qr.usado) {
    return res.json({ valido: false, motivo: 'Este QR ya fue utilizado.' });
  }
  if (qr.fecha_valida !== hoy) {
    return res.json({
      valido: false,
      motivo: `QR valido solo el ${qr.fecha_valida}. Hoy es ${hoy}.`,
    });
  }
  if (new Date(qr.expira_at) < new Date()) {
    return res.json({ valido: false, motivo: 'QR expirado.' });
  }

  // Marcar como usado (un solo ingreso)
  await supabaseAdmin.from('qr_accesos').update({ usado: true }).eq('id', qr.id);

  res.json({ valido: true, nombre: qr.perfiles?.nombre || 'Cliente' });
});

export default router;
