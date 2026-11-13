// Motor de diagnostico basado en reglas.
// Analiza las respuestas de la encuesta y genera un diagnostico
// mas recomendaciones. Determinista y sin dependencias externas.
// En una etapa futura puede reemplazarse por una llamada a LLM.

const PALABRAS_CLAVE = [
  'automatiza', 'inventario', 'ventas', 'nomina', 'clientes',
  'procesos', 'digitaliza', 'reportes', 'marketing', 'logistica',
];

function resumenRespuestas(respuestas, preguntas) {
  const mapa = new Map(preguntas.map((p) => [p.id, p]));
  const siNo = { si: 0, no: 0 };
  const escalas = [];
  const textos = [];
  const ops = { si: 0, no: 0 };

  for (const r of respuestas) {
    const p = mapa.get(r.pregunta_id);
    if (!p) continue;
    const v = r.respuesta;

    if (p.tipo === 'si_no') {
      const val = typeof v === 'string' ? v.toLowerCase() : v;
      if (val === 'si' || val === true) siNo.si++;
      else siNo.no++;
    } else if (p.tipo === 'escala' && typeof v === 'number') {
      escalas.push(v);
    } else if ((p.tipo === 'opcion_unica' || p.tipo === 'opcion_multiple')) {
      const vals = Array.isArray(v) ? v : [v];
      for (const x of vals) {
        const s = String(x).toLowerCase();
        if (['si', 'problema', 'necesito', 'urgente'].includes(s)) ops.si++;
        else ops.no++;
      }
    } else if (typeof v === 'string' && v.trim().length > 3) {
      textos.push(v.trim());
    }
  }
  return { siNo, escalas, textos, ops };
}

export function generarDiagnostico(respuestas, preguntas) {
  const { siNo, escalas, textos, ops } = resumenRespuestas(respuestas, preguntas);
  const totalSiNo = siNo.si + siNo.no;
  const totalOps = ops.si + ops.no;
  const promEscala = escalas.length
    ? (escalas.reduce((a, b) => a + b, 0) / escalas.length).toFixed(1)
    : null;

  // --- Diagnostico ---
  const lineas = [];
  if (totalSiNo > 0) {
    const pct = Math.round((siNo.si / totalSiNo) * 100);
    lineas.push(
      `El ${pct}% de los procesos consultados presentan oportunidades de mejora (${siNo.si} de ${totalSiNo}).`
    );
  }
  if (totalOps > 0) {
    lineas.push(
      `${ops.si} areas marcadas como prioritarias o con problemas de ${totalOps} evaluadas.`
    );
  }
  if (promEscala !== null) {
    lineas.push(`Puntaje promedio de madurez digital: ${promEscala}/10.`);
  }
  if (textos.length) {
    lineas.push(`El cliente describio ${textos.length} necesidad(es) en texto libre.`);
  }
  if (!lineas.length) {
    lineas.push('No se detectaron suficientes respuestas para generar un diagnostico automatico. Se recomienda una entrevista de descubrimiento.');
  }

  // --- Recomendaciones ---
  const recs = [];
  const todoTexto = textos.join(' ').toLowerCase();

  if (siNo.si > siNo.no) {
    recs.push('Priorizar la digitalizacion de los procesos internos antes de escalar.');
  }
  if (promEscala !== null && Number(promEscala) < 5) {
    recs.push('Implementar una fase de capacitacion y adopcion antes de nuevas herramientas.');
  } else if (promEscala !== null && Number(promEscala) >= 7) {
    recs.push('Evaluar integraciones avanzadas y automatizacion con IA.');
  }
  for (const kw of PALABRAS_CLAVE) {
    if (todoTexto.includes(kw)) {
      recs.push(`Atender la necesidad detectada relacionada con "${kw}".`);
    }
  }
  if (!recs.length) {
    recs.push('Agendar una sesion de profundizacion para definir el alcance del proyecto.');
    recs.push('Levantar un mapa de procesos actual antes de proponer solucion.');
  }

  // Deduplicar preservando orden
  const unicas = [...new Set(recs)];

  return {
    diagnostico: lineas.join('\n'),
    recomendaciones: unicas.map((r, i) => `${i + 1}. ${r}`).join('\n'),
  };
}
