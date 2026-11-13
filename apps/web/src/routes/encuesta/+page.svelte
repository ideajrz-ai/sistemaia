<script>
  import { onMount } from 'svelte';
  import { requireSession, apiFetch } from '$lib/auth.js';

  let cargando = true;
  let preguntas = [];
  let respuestas = {};   // pregunta_id -> valor
  let enviando = false;
  let error = '';
  let resultado = null;  // encuesta con diagnostico
  let historial = [];
  let detalle = null;    // encuesta seleccionada del historial

  onMount(async () => {
    await requireSession();
    try {
      const [p, e] = await Promise.all([
        apiFetch('/api/preguntas?activas=1'),
        apiFetch('/api/encuestas'),
      ]);
      preguntas = p.preguntas;
      historial = e.encuestas;
    } catch (err) {
      error = err.message;
    } finally {
      cargando = false;
    }
  });

  function setRespuesta(id, valor) {
    respuestas = { ...respuestas, [id]: valor };
  }

  function toggleOpcion(id, opcion) {
    const actual = Array.isArray(respuestas[id]) ? respuestas[id] : [];
    const nuevo = actual.includes(opcion)
      ? actual.filter((x) => x !== opcion)
      : [...actual, opcion];
    setRespuesta(id, nuevo);
  }

  function faltaObligatoria() {
    return preguntas.some((p) => {
      if (!p.obligatoria) return false;
      const v = respuestas[p.id];
      return v === undefined || v === null || v === '' || (Array.isArray(v) && !v.length);
    });
  }

  async function enviar() {
    error = '';
    enviando = true;
    try {
      const payload = Object.entries(respuestas).map(([pregunta_id, respuesta]) => ({
        pregunta_id,
        respuesta,
      }));
      const data = await apiFetch('/api/encuestas', {
        method: 'POST',
        body: JSON.stringify({ respuestas: payload }),
      });
      resultado = data.encuesta;
      historial = [resultado, ...historial];
      respuestas = {};
      window.scrollTo({ top: 0, behavior: 'smooth' });
    } catch (e) {
      error = e.message;
    } finally {
      enviando = false;
    }
  }

  async function verDetalle(id) {
    try {
      const data = await apiFetch(`/api/encuestas/${id}`);
      detalle = data;
    } catch (e) {
      error = e.message;
    }
  }
</script>

<svelte:head><title>Encuesta de diagnóstico · SistemaIA</title></svelte:head>

{#if cargando}
  <div class="tarjeta"><p class="tenue">Cargando…</p></div>
{:else}
  {#if resultado}
    <div class="tarjeta" style="border-color:var(--color-exito);">
      <h1>Diagnóstico generado</h1>
      <p class="tenue">Completada el {new Date(resultado.completada_at).toLocaleString('es')}</p>
      <h3>Diagnóstico</h3>
      <p style="white-space:pre-line;">{resultado.diagnostico}</p>
      <h3>Recomendaciones</h3>
      <p style="white-space:pre-line;">{resultado.recomendaciones}</p>
      <button class="boton boton-secundario" on:click={() => (resultado = null)}>Responder otra encuesta</button>
    </div>
  {/if}

  {#if detalle}
    <div class="tarjeta">
      <h2>Resultado del {new Date(detalle.encuesta.created_at).toLocaleDateString('es')}</h2>
      {#each detalle.respuestas as r}
        <div style="margin-bottom:0.75rem;">
          <strong>{r.preguntas_encuesta?.texto}</strong>
          <div class="tenue">{JSON.stringify(r.respuesta)}</div>
        </div>
      {/each}
      {#if detalle.encuesta.diagnostico}
        <h3>Diagnóstico</h3>
        <p style="white-space:pre-line;">{detalle.encuesta.diagnostico}</p>
        <h3>Recomendaciones</h3>
        <p style="white-space:pre-line;">{detalle.encuesta.recomendaciones}</p>
      {/if}
      <button class="boton boton-secundario" on:click={() => (detalle = null)}>Cerrar</button>
    </div>
  {/if}

  <div class="tarjeta">
    <h1>Encuesta de diagnóstico de necesidades</h1>
    {#if error}<p class="error">{error}</p>{/if}
    {#if preguntas.length === 0}
      <p class="tenue">No hay preguntas activas por ahora. Vuelve pronto.</p>
    {:else}
      {#each preguntas as p}
        <div class="tarjeta" style="background:#101013;">
          <h3 style="margin-top:0;">
            {p.orden}. {p.texto}
            {#if p.obligatoria}<span style="color:var(--color-error);"> *</span>{/if}
          </h3>

          {#if p.tipo === 'si_no'}
            <div style="display:flex; gap:1rem;">
              {#each ['si', 'no'] as op}
                <label style="display:flex; gap:0.4rem; align-items:center;">
                  <input type="radio" name="p-{p.id}" checked={respuestas[p.id] === op}
                    on:change={() => setRespuesta(p.id, op)} />
                  {op === 'si' ? 'Sí' : 'No'}
                </label>
              {/each}
            </div>

          {:else if p.tipo === 'opcion_unica'}
            {#each p.opciones ?? [] as op}
              <label style="display:flex; gap:0.4rem; align-items:center; margin-bottom:0.3rem;">
                <input type="radio" name="p-{p.id}" checked={respuestas[p.id] === op}
                  on:change={() => setRespuesta(p.id, op)} />
                {op}
              </label>
            {/each}

          {:else if p.tipo === 'opcion_multiple'}
            {#each p.opciones ?? [] as op}
              <label style="display:flex; gap:0.4rem; align-items:center; margin-bottom:0.3rem;">
                <input type="checkbox" checked={Array.isArray(respuestas[p.id]) && respuestas[p.id].includes(op)}
                  on:change={() => toggleOpcion(p.id, op)} />
                {op}
              </label>
            {/each}

          {:else if p.tipo === 'escala'}
            <div style="display:flex; gap:0.5rem; flex-wrap:wrap;">
              {#each Array.from({ length: 10 }, (_, i) => i + 1) as n}
                <label style="display:flex; gap:0.25rem; align-items:center;">
                  <input type="radio" name="p-{p.id}" checked={respuestas[p.id] === n}
                    on:change={() => setRespuesta(p.id, n)} />
                  {n}
                </label>
              {/each}
            </div>

          {:else if p.tipo === 'numero'}
            <input type="number" value={respuestas[p.id] ?? ''}
              on:input={(e) => setRespuesta(p.id, e.target.value === '' ? null : Number(e.target.value))} />

          {:else}
            <textarea rows="3" value={respuestas[p.id] ?? ''}
              on:input={(e) => setRespuesta(p.id, e.target.value)}></textarea>
          {/if}
        </div>
      {/each}

      {#if faltaObligatoria()}
        <p class="tenue">Responde las preguntas marcadas con * para continuar.</p>
      {/if}
      <button class="boton" on:click={enviar} disabled={enviando || faltaObligatoria()}>
        {enviando ? 'Enviando…' : 'Enviar y generar diagnóstico'}
      </button>
    {/if}
  </div>

  {#if historial.length}
    <div class="tarjeta">
      <h2>Mis encuestas anteriores</h2>
      <table class="tabla">
        <thead><tr><th>Fecha</th><th>Estado</th><th></th></tr></thead>
        <tbody>
          {#each historial as e}
            <tr>
              <td>{new Date(e.created_at).toLocaleDateString('es')}</td>
              <td>{e.estado}</td>
              <td><button class="boton boton-secundario" style="padding:0.3rem 0.7rem;" on:click={() => verDetalle(e.id)}>Ver</button></td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
{/if}
