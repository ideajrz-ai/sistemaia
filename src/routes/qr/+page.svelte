<script>
  import { onMount } from 'svelte';
  import { requireSession, apiFetch } from '$lib/auth.js';

  let cargando = true;
  let historial = [];
  let qr = null;          // { qr: dataURL, fecha_valida }
  let generando = false;
  let error = '';
  let fecha = new Date().toISOString().slice(0, 10);

  onMount(async () => {
    await requireSession();
    try {
      const data = await apiFetch('/api/qr/mios');
      historial = data.qr;
    } catch (e) {
      error = e.message;
    } finally {
      cargando = false;
    }
  });

  async function generar() {
    error = '';
    generando = true;
    try {
      const data = await apiFetch('/api/qr', {
        method: 'POST',
        body: JSON.stringify({ fecha }),
      });
      qr = data;
      const h = await apiFetch('/api/qr/mios');
      historial = h.qr;
    } catch (e) {
      error = e.message;
    } finally {
      generando = false;
    }
  }
</script>

<svelte:head><title>QR de acceso · SistemaIA</title></svelte:head>

{#if cargando}
  <div class="tarjeta"><p class="tenue">Cargando…</p></div>
{:else}
  <div class="tarjeta">
    <h1>QR de acceso a la oficina</h1>
    <p class="tenue">
      Genera tu QR para el día de tu cita. Es válido solo ese día y permite un solo ingreso.
      En recepción se escanea desde la página de validación.
    </p>
    {#if error}<p class="error">{error}</p>{/if}
  </div>

  <div class="tarjeta" style="text-align:center;">
    <div class="campo" style="max-width:220px; margin:0 auto 1rem;">
      <label>Fecha de acceso</label>
      <input type="date" bind:value={fecha} min={new Date().toISOString().slice(0, 10)} />
    </div>
    <button class="boton" on:click={generar} disabled={generando}>
      {generando ? 'Generando…' : 'Generar QR'}
    </button>

    {#if qr}
      <div style="margin-top:1.5rem;">
        <img src={qr.qr} alt="QR de acceso" style="border-radius:12px; background:#fff; padding:8px;" />
        <p class="tenue">Válido el <strong>{qr.fecha_valida}</strong> · un solo uso</p>
        <p class="tenue" style="font-size:0.8rem;">Toma captura o imprime esta imagen para mostrarla en recepción.</p>
      </div>
    {/if}
  </div>

  {#if historial.length}
    <div class="tarjeta">
      <h2>QR generados</h2>
      <table class="tabla">
        <thead><tr><th>Fecha válida</th><th>Estado</th><th>Generado</th></tr></thead>
        <tbody>
          {#each historial as q}
            <tr>
              <td>{q.fecha_valida}</td>
              <td>{q.usado ? 'Usado' : new Date(q.expira_at) < new Date() ? 'Expirado' : 'Vigente'}</td>
              <td>{new Date(q.created_at).toLocaleString('es')}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
{/if}
