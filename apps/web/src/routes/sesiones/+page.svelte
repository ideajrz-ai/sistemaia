<script>
  import { onMount } from 'svelte';
  import { requireSession, apiFetch } from '$lib/auth.js';

  let cargando = true;
  let sesiones = [];
  let error = '';
  let form = { titulo: '', descripcion: '', fecha: '', hora_inicio: '', duracion_min: 60, notas: '' };
  let guardando = false;
  let esAdmin = false;

  onMount(async () => {
    const session = await requireSession();
    if (!session) return;
    try {
      const me = await apiFetch('/api/me');
      esAdmin = me.perfil?.rol === 'admin';
      await cargar();
    } catch (e) {
      error = e.message;
    } finally {
      cargando = false;
    }
  });

  async function cargar() {
    const data = await apiFetch('/api/sesiones');
    sesiones = data.items;
  }

  async function crear() {
    error = '';
    guardando = true;
    try {
      await apiFetch('/api/sesiones', {
        method: 'POST',
        body: JSON.stringify({
          titulo: form.titulo,
          descripcion: form.descripcion || null,
          fecha: form.fecha,
          hora_inicio: form.hora_inicio || null,
          duracion_min: Number(form.duracion_min) || 60,
          notas: form.notas || null,
        }),
      });
      form = { titulo: '', descripcion: '', fecha: '', hora_inicio: '', duracion_min: 60, notas: '' };
      await cargar();
    } catch (e) {
      error = e.message;
    } finally {
      guardando = false;
    }
  }

  async function cambiarEstado(s, estado) {
    try {
      await apiFetch(`/api/sesiones/${s.id}`, { method: 'PATCH', body: JSON.stringify({ estado }) });
      await cargar();
    } catch (e) {
      error = e.message;
    }
  }

  async function eliminar(s) {
    if (!confirm(`¿Eliminar la sesion "${s.titulo}"?`)) return;
    try {
      await apiFetch(`/api/sesiones/${s.id}`, { method: 'DELETE' });
      await cargar();
    } catch (e) {
      error = e.message;
    }
  }
</script>

<svelte:head><title>Sesiones · SistemaIA</title></svelte:head>

{#if cargando}
  <div class="tarjeta"><p class="tenue">Cargando…</p></div>
{:else}
  <div class="tarjeta">
    <h1>Sesiones de consultoría</h1>
    {#if error}<p class="error">{error}</p>{/if}
  </div>

  <div class="tarjeta">
    <h2>Nueva sesión</h2>
    <div style="display:flex; gap:1rem; flex-wrap:wrap;">
      <div class="campo" style="flex:2; min-width:200px;">
        <label>Título</label>
        <input type="text" bind:value={form.titulo} placeholder="Ej. Descubrimiento inicial" />
      </div>
      <div class="campo" style="flex:1; min-width:150px;">
        <label>Fecha</label>
        <input type="date" bind:value={form.fecha} />
      </div>
      <div class="campo" style="width:140px;">
        <label>Hora</label>
        <input type="time" bind:value={form.hora_inicio} />
      </div>
      <div class="campo" style="width:120px;">
        <label>Duración (min)</label>
        <input type="number" bind:value={form.duracion_min} min="15" step="15" />
      </div>
    </div>
    <div class="campo">
      <label>Descripción</label>
      <textarea rows="2" bind:value={form.descripcion}></textarea>
    </div>
    <div class="campo">
      <label>Notas</label>
      <textarea rows="2" bind:value={form.notas}></textarea>
    </div>
    <button class="boton" on:click={crear} disabled={guardando || !form.titulo || !form.fecha}>
      {guardando ? 'Guardando…' : 'Agendar sesión'}
    </button>
  </div>

  <div class="tarjeta">
    <h2>Historial</h2>
    {#if sesiones.length === 0}
      <p class="tenue">Aún no hay sesiones.</p>
    {:else}
      <table class="tabla">
        <thead><tr><th>Fecha</th><th>Título</th><th>Hora</th><th>Estado</th><th></th></tr></thead>
        <tbody>
          {#each sesiones as s}
            <tr>
              <td>{s.fecha}</td>
              <td>{s.titulo}<div class="tenue" style="font-size:0.8rem;">{s.descripcion || ''}</div></td>
              <td>{s.hora_inicio || '—'}</td>
              <td>{s.estado}</td>
              <td style="white-space:nowrap;">
                {#if s.estado === 'programada'}
                  <button class="boton boton-secundario" style="padding:0.3rem 0.6rem;" on:click={() => cambiarEstado(s, 'realizada')}>Realizada</button>
                  <button class="boton boton-secundario" style="padding:0.3rem 0.6rem;" on:click={() => cambiarEstado(s, 'cancelada')}>Cancelar</button>
                {/if}
                <button class="boton boton-secundario" style="padding:0.3rem 0.6rem;" on:click={() => eliminar(s)}>Borrar</button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
{/if}
