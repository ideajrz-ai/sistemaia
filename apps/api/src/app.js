import 'dotenv/config';
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { rateLimit } from 'express-rate-limit';
import { supabaseAdmin } from './lib/supabase.js';
import { requireAuth, requireRole } from './middleware/auth.js';
import preguntasRouter from './routes/preguntas.js';
import encuestasRouter from './routes/encuestas.js';
import sesionesRouter from './routes/sesiones.js';
import citasRouter from './routes/citas.js';
import archivosRouter from './routes/archivos.js';
import qrRouter from './routes/qr.js';
import adminRouter from './routes/admin.js';

const app = express();

// --- Seguridad base ---
app.use(helmet());
app.use(cors({
  origin: (origin, cb) => {
    // En desarrollo acepta localhost/127.0.0.1 en cualquier puerto
    // (vite dev, previews del IDE, etc.)
    if (!origin || /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
      return cb(null, true);
    }
    const allowed = (process.env.APP_URL || 'http://localhost:5173')
      .split(',').map((s) => s.trim());
    cb(null, allowed.includes(origin));
  },
  credentials: true,
}));
app.use(express.json({ limit: '4mb' }));

// Balance de carga: limite global de peticiones por IP
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 300,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
});
app.use(globalLimiter);

// Balance de carga estricto para endpoints sensibles
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { error: 'Demasiados intentos. Intenta de nuevo en unos minutos.' },
});

// --- Rutas publicas ---
app.get('/api/health', (_req, res) => {
  res.json({ ok: true, service: 'sistema-ia-api', time: new Date().toISOString() });
});

// --- Rutas protegidas: requieren JWT valido de Supabase ---
app.get('/api/me', requireAuth, async (req, res) => {
  const { data: perfil } = await supabaseAdmin
    .from('perfiles')
    .select('*')
    .eq('id', req.user.id)
    .single();

  res.json({ user: req.user, perfil: perfil ?? null });
});

// Actualizar perfil propio (cliente o admin)
app.patch('/api/me', requireAuth, async (req, res) => {
  const permitidos = ['nombre', 'telefono', 'direccion', 'necesidad'];
  const cambios = {};
  for (const k of permitidos) {
    if (req.body[k] !== undefined) cambios[k] = req.body[k];
  }
  if (Object.keys(cambios).length === 0) {
    return res.status(400).json({ error: 'No hay campos validos para actualizar.' });
  }

  const { data, error } = await supabaseAdmin
    .from('perfiles')
    .update(cambios)
    .eq('id', req.user.id)
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json({ perfil: data });
});

// --- Solo administradores ---
app.get('/api/admin/clientes', requireAuth, requireRole('admin'), async (_req, res) => {
  const { data, error } = await supabaseAdmin
    .from('perfiles')
    .select('id, nombre, email, telefono, direccion, necesidad, rol, modulos_visibles, created_at')
    .eq('rol', 'cliente')
    .order('created_at', { ascending: false });

  if (error) return res.status(500).json({ error: error.message });
  res.json({ clientes: data });
});

// --- Modulos ---
app.use('/api/preguntas', preguntasRouter);
app.use('/api/encuestas', encuestasRouter);
app.use('/api/sesiones', sesionesRouter);
app.use('/api/citas', citasRouter);
app.use('/api/archivos', archivosRouter);
app.use('/api/qr', qrRouter);
app.use('/api/admin', adminRouter);

// Placeholder para futuras rutas con limite estricto
app.post('/api/auth/*', authLimiter, (_req, res) => {
  res.status(404).json({ error: 'Ruta no implementada.' });
});

// 404
app.use((_req, res) => res.status(404).json({ error: 'Ruta no encontrada.' }));

// Error handler
// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(err.status || 500).json({ error: 'Error interno del servidor.' });
});

export default app;
