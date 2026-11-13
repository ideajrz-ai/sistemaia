<script>
  import { onMount } from 'svelte';
  import { requireSession, apiFetch } from '$lib/auth.js';
  import { supabase } from '$lib/supabase.js';

  const BUCKET = 'archivos-consultoria';

  let cargando = true;
  let archivos = [];
  let sesiones = [];
  let error = '';
  let aviso = '';
  let subiendo = false;
  let sesionSel = '';

  onMount(async () => {
    const session = await requireSession();
    if (!session) return;
    try {
      const [a, s] = await Promise.all([
        apiFetch('/api/archivos'),
        apiFetch('/api/sesiones'),
      ]);
      archivos = a.archivos;
      sesiones = s.items;
    } catch (e) {
      error = e.message;
    } finally {
      cargando = false;
    }
  });

  async function subir(event) {
    error = '';
    aviso = '';
    const file = event.target.files?.[0];
    if (!file) return;
    if (file.size > 20 * 1024 * 1024) {
      error = 'El archivo supera 20 MB.';
      return;
    }
    subiendo = true;
    try {
      const { data: { user } } = await supabase.auth.getUser();
      const safe = file.name.replace(/[^\w.\-]/g, '_');
      const ruta = `${user.id}/${crypto.randomUUID()}-${safe}`;

      const { error: errUp } = await supabase.storage
        .from(BUCKET)
        .upload(ruta, file, { upsert: false });
      if (errUp) throw new Error(errUp.message);

      await apiFetch('/api/archivos', {
        method: 'POST',
        body: JSON.stringify({
          nombre: file.name,
          tipo_mime: file.type || null,
          tamano_bytes: file.size,
          ruta_storage: ruta,
          sesion_id: sesionSel || null,
        }),
      });

      aviso = `"${file.name}" subido correctamente.`;
      event.target.value = '';
      const data = await apiFetch('/api/archivos');
      archivos = data.archivos;
    } catch (e) {
      error = e.message;
    } finally {
      subiendo = false;
    }
  }

  async function descargar(a) {
    try {
      const { url } = await apiFetch(`/api/archivos/${a.id}/url`);
      window.open(url, '_blank');
    } catch (e) {
      error = e.message;
    }
  }

  async function eliminar(a) {
    if (!confirm(`¿Eliminar "${a.nombre}"?`)) return;
    try {
      await apiFetch(`/api/archivos/${a.id}`, { method: 'DELETE' });
      archivos = archivos.filter((x) => x.id !== a.id);
    } catch (e) {
      error = e.message;
    }
  }

  function fmtBytes(b) {
    if (!b) return '—';
    if (b < 1024) return `${b} B`;
    if (b < 1024 * 1024) return `${(b / 1024).toFixed(1)} KB`;
    return `${(b / (1024 * 1024)).toFixed(1)} MB`;
  }
</script>

<svelte:head><title>Archivos · SistemaIA</title></svelte:head>

{#if cargando}
  <div class="tarjeta"><p class="tenue">Cargando…</p></div>
{:else}
  <div class="tarjeta">
    <h1>Archivos y documentos</h1>
    <p class="tenue">PDFs, imágenes, hojas de cálculo — hasta 20 MB por archivo.</p>
    {#if error}<p class="error">{error}</p>{/if}
    {#if aviso}<p class="exito">{aviso}</p>{/if}
  </div>

  <div class="tarjeta">
    <h2>Subir archivo</h2>
    <div class="campo" style="max-width:320px;">
      <label>Vincular a sesión (opcional)</label>
      <select bind:value={sesionSel}>
        <option value="">— Sin sesión —</option>
        {#each sesiones as s}<option value={s.id}>{s.titulo} ({s.fecha})</option>{/each}
      </select>
    </div>
    <input type="file" on:change={subir} disabled={subiendo}
      accept=".pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.csv,.png,.jpg,.jpeg,.webp,.gif,.zip" />
    {#if subiendo}<p class="tenue">Subiendo…</p>{/if}
  </div>

  <div class="tarjeta">
    <h2>Mis archivos ({archivos.length})</h2>
    {#if archivos.length === 0}
      <p class="tenue">No hay archivos todavía.</p>
    {:else}
      <table class="tabla">
        <thead><tr><th>Nombre</th><th>Sesión</th><th>Tamaño</th><th>Fecha</th><th></th></tr></thead>
        <tbody>
          {#each archivos as a}
            <tr>
              <td>{a.nombre}<div class="tenue" style="font-size:0.8rem;">{a.tipo_mime || ''}</div></td>
              <td>{a.sesiones?.titulo || '—'}</td>
              <td>{fmtBytes(a.tamano_bytes)}</td>
              <td>{new Date(a.created_at).toLocaleDateString('es')}</td>
              <td style="white-space:nowrap;">
                <button class="boton boton-secundario" style="padding:0.3rem 0.6rem;" on:click={() => descargar(a)}>Ver</button>
                <button class="boton boton-secundario" style="padding:0.3rem 0.6rem;" on:click={() => eliminar(a)}>Borrar</button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
{/if}
