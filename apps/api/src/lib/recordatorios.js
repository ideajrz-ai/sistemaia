import { supabaseAdmin } from './supabase.js';

// Procesa los recordatorios de citas pendientes.
// - Email: requiere SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS en .env
// - WhatsApp: requiere WHATSAPP_API_URL y WHATSAPP_TOKEN (API tipo 360dialog/Meta)
// - Si no hay credenciales, registra como 'simulado' para no perder trazabilidad.

async function enviarEmail({ para, asunto, texto }) {
  if (!process.env.SMTP_HOST) return { ok: false, motivo: 'SMTP no configurado' };
  const nodemailer = (await import('nodemailer')).default;
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT || 587),
    secure: process.env.SMTP_SECURE === 'true',
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  });
  await transporter.sendMail({
    from: process.env.SMTP_FROM || process.env.SMTP_USER,
    to: para,
    subject: asunto,
    text: texto,
  });
  return { ok: true };
}

async function enviarWhatsApp({ para, texto }) {
  if (!process.env.WHATSAPP_API_URL || !process.env.WHATSAPP_TOKEN) {
    return { ok: false, motivo: 'WhatsApp API no configurada' };
  }
  const res = await fetch(process.env.WHATSAPP_API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${process.env.WHATSAPP_TOKEN}`,
    },
    body: JSON.stringify({ to: para, body: texto }),
  });
  if (!res.ok) return { ok: false, motivo: `WhatsApp respondio ${res.status}` };
  return { ok: true };
}

function mensajeCita(cita, perfil) {
  const f = new Date(cita.fecha_inicio);
  const fecha = f.toLocaleString('es', { dateStyle: 'full', timeStyle: 'short' });
  return (
    `Hola ${perfil?.nombre || ''}, te recordamos tu cita "${cita.titulo}" ` +
    `programada para el ${fecha}. — SistemaIA Consultoría`
  );
}

export async function procesarRecordatorios() {
  const ahora = new Date();

  // Citas futuras cuya ventana de recordatorio ya abrio
  const { data: citas, error } = await supabaseAdmin
    .from('citas')
    .select('*, perfiles!citas_cliente_id_fkey(nombre, email, telefono)')
    .eq('recordatorio_enviado', false)
    .gt('fecha_inicio', ahora.toISOString())
    .lte(
      'fecha_inicio',
      new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString() // horizonte 7 dias
    );

  if (error) throw error;

  const resultados = [];
  for (const cita of citas || []) {
    const minutosAntes = (new Date(cita.fecha_inicio) - ahora) / 60000;
    if (minutosAntes > cita.recordatorio_min) continue; // aun no toca

    const perfil = cita.perfiles;
    const msg = mensajeCita(cita, perfil);

    // Email
    if (perfil?.email) {
      try {
        const r = await enviarEmail({
          para: perfil.email,
          asunto: `Recordatorio: ${cita.titulo}`,
          texto: msg,
        });
        await supabaseAdmin.from('recordatorios_log').insert({
          cita_id: cita.id,
          cliente_id: cita.cliente_id,
          canal: 'email',
          destino: perfil.email,
          estado: r.ok ? 'enviado' : r.motivo?.includes('no configurado') ? 'simulado' : 'fallido',
          detalle: r.ok ? null : r.motivo,
        });
        resultados.push({ cita: cita.id, canal: 'email', ...r });
      } catch (e) {
        await supabaseAdmin.from('recordatorios_log').insert({
          cita_id: cita.id, cliente_id: cita.cliente_id, canal: 'email',
          destino: perfil.email, estado: 'fallido', detalle: e.message,
        });
      }
    }

    // WhatsApp
    if (perfil?.telefono) {
      try {
        const r = await enviarWhatsApp({ para: perfil.telefono, texto: msg });
        await supabaseAdmin.from('recordatorios_log').insert({
          cita_id: cita.id,
          cliente_id: cita.cliente_id,
          canal: 'whatsapp',
          destino: perfil.telefono,
          estado: r.ok ? 'enviado' : r.motivo?.includes('no configurada') ? 'simulado' : 'fallido',
          detalle: r.ok ? null : r.motivo,
        });
        resultados.push({ cita: cita.id, canal: 'whatsapp', ...r });
      } catch (e) {
        await supabaseAdmin.from('recordatorios_log').insert({
          cita_id: cita.id, cliente_id: cita.cliente_id, canal: 'whatsapp',
          destino: perfil.telefono, estado: 'fallido', detalle: e.message,
        });
      }
    }

    await supabaseAdmin
      .from('citas')
      .update({ recordatorio_enviado: true })
      .eq('id', cita.id);
  }

  return { procesadas: resultados.length, resultados };
}
