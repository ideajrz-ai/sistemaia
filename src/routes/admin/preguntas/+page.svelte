<script>
  import { onMount } from 'svelte';
  import { requireSession, apiFetch } from '$lib/auth.js';

  const TIPOS = ['si_no', 'opcion_unica', 'opcion_multiple', 'texto', 'numero', 'escala'];

  let cargando = true;
  let esAdmin = false;
  let preguntas = [];
  let error = '';
  let aviso = '';

  // formulario
  let form = { texto: '', tipo: 'si_no', opciones: '', orden: 0 };
  let guardando = false;
  let editando = null; // id en edicion o null

  onMount(async () => {
    await requireSession();
    try {
      const data = await apiFetch('/api/me');
      esAdmin = data.perfil?.rol === 'admin';
      if (!esAdmin) {
        error = 'Solo administradores pueden gestionar preguntas.';
        return;
      }
      await cargar();
    } catch (e) {
      error = e.message;
    } finally {
      cargando = false;
    }
  });

  async function cargar() {
    const data = await apiFetch('/api/preguntas');
    preguntas = data.preguntas;
  }

  function opcionesArray() {
    return form.opciones
      .split('\n')
      .map((s) => s.trim())
      .filter(Boolean);
  }

  async function guardar() {
    error = '';
    aviso = '';
    guardando = true;
    try {
      const usaOpciones = ['opcion_unica', 'opcion_multiple'].includes(form.tipo);
      const body = {
        texto: form.texto,
        tipo: form.tipo,
        opciones: usaOpciones ? opcionesArray() : null,
        orden: Number(form.orden) || 0,
      };
      if (editando) {
        await apiFetch(`/api/preguntas/${editando}`, { method: 'PATCH', body: JSON.stringify(body) });
        aviso = 'Pregunta actualizada.';
      } else {
        await apiFetch('/api/preguntas', { method: 'POST', body: JSON.stringify(body) });
        aviso = 'Pregunta creada.';
      }
      form = { texto: '', tipo: 'si_no', opciones: '', orden: 0 };
      editando = null;
      await cargar();
    } catch (e) {
      error = e.message;
    } finally {
      guardando = false;
    }
  }

  function editar(p) {
    editando = p.id;
    form = {
      texto: p.texto,
      tipo: p.tipo,
      opciones: Array.isArray(p.opciones) ? p.opciones.join('\n') : '',
      orden: p.orden,
    };
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  async function toggleActiva(p) {
    try {
      await apiFetch(`/api/preguntas/${p.id}`, {
        method: 'PATCH',
        body: JSON.stringify({ activa: !p.activa }),
      });
      await cargar();
    } catch (e) {
      error = e.message;
    }
  }

  async function eliminar(p) {
    if (!confirm(`¿Desactivar la pregunta "${p.texto.slice(0, 50)}…"?`)) return;
    try {
      await apiFetch(`/api/preguntas/${p.id}`, { method: 'DELETE' });
      await cargar();
    } catch (e) {
      error = e.message;
    }
  }
</script>

<svelte:head><title>Preguntas de encuesta · Admin</title></svelte:head>

{#if cargando}
  <div class="tarjeta"><p class="tenue">Cargando…</p></div>
{:else if !esAdmin}
  <div class="tarjeta"><p class="error">{error}</p></div>
{:else}
  <div class="tarjeta">
    <h1>Preguntas de la encuesta</h1>
    <p class="tenue">{preguntas.length} pregunta(s). Las inactivas no aparecen en la encuesta del cliente.</p>
    {#if error}<p class="error">{error}</p>{/if}
    {#if aviso}<p class="exito">{aviso}</p>{/if}
  </div>

  <div class="tarjeta">
    <h2>{editando ? 'Editar pregunta' : 'Nueva pregunta'}</h2>
    <div class="campo">
      <label>Texto de la pregunta</label>
      <textarea rows="2" bind:value={form.texto} placeholder="Ej. ¿Qué procesos realizas manualmente?"></textarea>
    </div>
    <div style="display:flex; gap:1rem; flex-wrap:wrap;">
      <div class="campo" style="flex:1; min-width:200px;">
        <label>Tipo</label>
        <select bind:value={form.tipo}>
          {#each TIPOS as t}<option value={t}>{t.replace('_', ' ')}</option>{/each}
        </select>
      </div>
      <div class="campo" style="width:120px;">
        <label>Orden</label>
        <input type="number" bind:value={form.orden} />
      </div>
    </div>
    {#if ['opcion_unica', 'opcion_multiple'].includes(form.tipo)}
      <div class="campo">
        <label>Opciones (una por línea)</label>
        <textarea rows="4" bind:value={form.opciones} placeholder="Ventas&#10;Inventario&#10;Nomina"></textarea>
      </div>
    {/if}
    <div style="display:flex; gap:0.75rem;">
      <button class="boton" on:click={guardar} disabled={guardando || !form.texto.trim()}>
        {guardando ? 'Guardando…' : editando ? 'Actualizar' : 'Crear'}
      </button>
      {#if editando}
        <button class="boton boton-secundario" on:click={() => { editando = null; form = { texto: '', tipo: 'si_no', opciones: '', orden: 0 }; }}>
          Cancelar
        </button>
      {/if}
    </div>
  </div>

  <div class="tarjeta">
    <h2>Lista</h2>
    {#if preguntas.length === 0}
      <p class="tenue">No hay preguntas. Crea la primera arriba.</p>
    {:else}
      {#each preguntas as p}
        <div class="tarjeta" style="background:#101013; margin-bottom:0.75rem;">
          <div style="display:flex; justify-content:space-between; gap:1rem; align-items:start;">
            <div>
              <strong>{p.orden}. {p.texto}</strong>
              <div class="tenue" style="font-size:0.85rem; margin-top:0.25rem;">
                {p.tipo.replace('_', ' ')} · {p.obligatoria ? 'obligatoria' : 'opcional'}
                {#if !p.activa} · <span style="color:var(--color-error)">inactiva</span>{/if}
              </div>
              {#if Array.isArray(p.opciones) && p.opciones.length}
                <div class="tenue" style="font-size:0.85rem;">Opciones: {p.opciones.join(', ')}</div>
              {/if}
            </div>
            <div style="display:flex; gap:0.5rem; flex-shrink:0;">
              <button class="boton boton-secundario" style="padding:0.4rem 0.8rem;" on:click={() => editar(p)}>Editar</button>
              <button class="boton boton-secundario" style="padding:0.4rem 0.8rem;" on:click={() => toggleActiva(p)}>
                {p.activa ? 'Desactivar' : 'Activar'}
              </button>
              <button class="boton boton-secundario" style="padding:0.4rem 0.8rem;" on:click={() => eliminar(p)}>Borrar</button>
            </div>
          </div>
        </div>
      {/each}
    {/if}
  </div>
{/if}
