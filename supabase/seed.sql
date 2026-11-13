-- ============================================================
-- SISTEMAIA · Datos de ejemplo (seed)
-- Ejecutar en Supabase SQL Editor DESPUÉS de schema.sql
-- ============================================================

-- ---------- Preguntas de ejemplo para la encuesta de diagnostico ----------
insert into public.preguntas_encuesta (texto, tipo, opciones, obligatoria, orden) values

('¿Qué procesos de tu negocio realizas de forma manual?', 'opcion_multiple',
 '["Ventas","Inventario","Nomina","Facturacion","Atencion a clientes","Reportes"]'::jsonb,
 true, 1),

('¿Con qué frecuencia tu equipo usa herramientas digitales?', 'opcion_unica',
 '["Nunca","Rara vez","Algunas veces","Casi siempre","Siempre"]'::jsonb,
 true, 2),

('¿Tus datos estan centralizados en un solo sistema?', 'si_no', null, true, 3),

('¿Cuántas horas semanales pierde tu equipo en tareas repetitivas?', 'escala', null, true, 4),

('¿Qué area necesita atencion prioritaria?', 'opcion_unica',
 '["Ventas","Operaciones","Finanzas","Recursos humanos","Marketing","Logistica"]'::jsonb,
 true, 5),

('¿Tienes presencia digital (sitio web, redes sociales)?', 'si_no', null, false, 6),

('Describe brevemente el problema principal que quieres resolver:', 'texto', null, true, 7);

-- ---------- Ejemplo de cita (descomenta y pon tu user id si quieres probar) ----------
-- insert into public.citas (cliente_id, titulo, fecha_inicio, recordatorio_min)
-- values ('UUID-DE-TU-USUARIO', 'Primera sesion de diagnostico', now() + interval '2 days', 1440);
