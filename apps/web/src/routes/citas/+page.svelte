<script>
  import { onMount } from 'svelte';
  import { requireSession, apiFetch } from '$lib/auth.js';

  let cargando = true;
  let citas = [];
  let error = '';
  let form = { titulo: '', fecha_inicio: '', fecha_fin: '', notas: '', recordatorio_min: 1440 };
  let guardando = false;

  onMount(async () => {
    await requireSession();
    try {
      await cargar();
    } catch (e) {
      error = e.message;
    } finally {
      cargando = false;
    }
  });

  async function cargar() {
    const data = await apiFetch('/api/citas');
    citas = data.items.sort((a, b) => new Date(a.fecha_inicio) - new Date(b.fecha_inicio));
  }

  function toIso(local) {
    // input datetime-local -> ISO
    return local ? new Date(local).toISOString() : null;
  }

  async function crear() {
    error = '';
    guardando = true;
    try {
      await apiFetch('/api/citas', {
        method: 'POST',
        body: JSON.stringify({
          titulo: form.titulo,
          fecha_inicio: toIso(form.fecha_inicio),
          fecha_fin: toIso(form.fecha_fin),
          notas: form.notas || null,
          recordatorio_min: Number(form.recordatorio_min) || 1440,
        }),
      });
      form = { titulo: '', fecha_inicio: '', fecha_fin: '', notas: '', recordatorio_min: 1440 };
      await cargar();
    } catch (e) {
      error = e.message;
    } finally {
      guardando = false;
    }
  }

  async function eliminar(c) {
    if (!confirm(`¿Eliminar la cita "${c.titulo}"?`)) return;
    try {
      await apiFetch(`/api/citas/${c.id}`, { method: 'DELETE' });
      await cargar();
    } catch (e) {
      error = e.message;
    }
  }

  function fmtRecordatorio(min) {
    if (min >= 1440) return `${Math.round(min / 1440)} día(s) antes`;
    if (min >= 60) return `${Math.round(min / 60)} h antes`;
    return `${min} min antes`;
  }
</script>

<svelte:head><title>Citas · SistemaIA</title></svelte:head>

{#if cargando}
  <div class="tarjeta"><p class="tenue">Cargando…</p></div>
{:else}
  <div class="tarjeta">
    <h1>Calendario de citas</h1>
    <p class="tenue">Recibirás recordatorio por correo y/o WhatsApp antes de cada cita.</p>
    {#if error}<p class="error">{error}</p>{/if}
  </div>

  <div class="tarjeta">
    <h2>Agendar cita</h2>
    <div style="display:flex; gap:1rem; flex-wrap:wrap;">
      <div class="campo" style="flex:2; min-width:200px;">
        <label>Título</label>
        <input type="text" bind:value={form.titulo} placeholder="Ej. Sesión de seguimiento" />
      </div>
      <div class="campo" style="flex:1; min-width:200px;">
        <label>Inicio</label>
        <input type="datetime-local" bind:value={form.fecha_inicio} />
      </div>
      <div class="campo" style="flex:1; min-width:200px;">
        <label>Fin (opcional)</label>
        <input type="datetime-local" bind:value={form.fecha_fin} />
      </div>
      <div class="campo" style="width:160px;">
        <label>Recordatorio</label>
        <select bind:value={form.recordatorio_min}>
          <option value={60}>1 hora antes</option>
          <option value={240}>4 horas antes</option>
          <option value={1440}>1 día antes</option>
          <option value={2880}>2 días antes</option>
        </select>
      </div>
    </div>
    <div class="campo">
      <label>Notas</label>
      <textarea rows="2" bind:value={form.notas}></textarea>
    </div>
    <button class="boton" on:click={crear} disabled={guardando || !form.titulo || !form.fecha_inicio}>
      {guardando ? 'Guardando…' : 'Agendar'}
    </button>
  </div>

  <div class="tarjeta">
    <h2>Próximas y pasadas</h2>
    {#if citas.length === 0}
      <p class="tenue">No hay citas agendadas.</p>
    {:else}
      <table class="tabla">
        <thead><tr><th>Fecha</th><th>Título</th><th>Recordatorio</th><th>Estado</th><th></th></tr></thead>
        <tbody>
          {#each citas as c}
            {@const futura = new Date(c.fecha_inicio) > new Date()}
            <tr style={futura ? '' : 'opacity:0.55;'}>
              <td>{new Date(c.fecha_inicio).toLocaleString('es', { dateStyle: 'medium', timeStyle: 'short' })}</td>
              <td>{c.titulo}<div class="tenue" style="font-size:0.8rem;">{c.notas || ''}</div></td>
              <td>{fmtRecordatorio(c.recordatorio_min)}{c.recordatorio_enviado ? ' ✓ enviado' : ''}</td>
              <td>{futura ? 'Programada' : 'Pasada'}</td>
              <td><button class="boton boton-secundario" style="padding:0.3rem 0.6rem;" on:click={() => eliminar(c)}>Borrar</button></td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
{/if}
