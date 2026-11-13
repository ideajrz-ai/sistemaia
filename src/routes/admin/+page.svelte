<script>
  import { onMount } from 'svelte';
  import { requireSession, apiFetch } from '$lib/auth.js';
  import { supabase } from '$lib/supabase.js';

  let cargando = true;
  let esAdmin = false;
  let clientes = [];
  let error = '';

  onMount(async () => {
    const session = await requireSession();
    if (!session) return;

    const { data: perfil } = await supabase
      .from('perfiles')
      .select('rol')
      .eq('id', session.user.id)
      .single();

    if (!perfil || perfil.rol !== 'admin') {
      cargando = false;
      error = 'Acceso denegado: se requiere rol de administrador.';
      return;
    }
    esAdmin = true;

    try {
      const data = await apiFetch('/api/admin/clientes');
      clientes = data.clientes;
    } catch (e) {
      error = e.message;
    } finally {
      cargando = false;
    }
  });
</script>

<svelte:head><title>Admin · SistemaIA</title></svelte:head>

{#if cargando}
  <div class="tarjeta"><p class="tenue">Cargando…</p></div>
{:else if !esAdmin}
  <div class="tarjeta"><p class="error">{error}</p></div>
{:else}
  <div class="tarjeta">
    <h1>Panel de administración</h1>
    <p class="tenue">{clientes.length} cliente(s) registrado(s)</p>
    <div style="display:flex; gap:0.75rem; flex-wrap:wrap; margin-top:1rem;">
      <a class="boton boton-secundario" href="/admin/preguntas">Preguntas de encuesta</a>
      <a class="boton boton-secundario" href="/admin/clientes">Clientes y módulos</a>
      <a class="boton boton-secundario" href="/admin/anuncios">Anuncios</a>
    </div>
  </div>

  <div class="tarjeta">
    <h2>Clientes recientes</h2>
    {#if error}<p class="error">{error}</p>{/if}
    {#if clientes.length === 0}
      <p class="tenue">Aún no hay clientes registrados.</p>
    {:else}
      <table class="tabla">
        <thead>
          <tr><th>Nombre</th><th>Correo</th><th>Teléfono</th><th>Alta</th></tr>
        </thead>
        <tbody>
          {#each clientes.slice(0, 10) as c}
            <tr>
              <td>{c.nombre || '—'}</td>
              <td>{c.email}</td>
              <td>{c.telefono || '—'}</td>
              <td>{new Date(c.created_at).toLocaleDateString('es')}</td>
            </tr>
          {/each}
        </tbody>
      </table>
      {#if clientes.length > 10}
        <p class="tenue">…y {clientes.length - 10} más en <a href="/admin/clientes">Clientes y módulos</a></p>
      {/if}
    {/if}
  </div>

  <div class="tarjeta">
    <h2>Operación</h2>
    <ul class="tenue">
      <li><strong>Recordatorios:</strong> se procesan con
        <code>POST /api/admin/recordatorios/procesar</code> (admin o cron con <code>x-cron-secret</code>).</li>
      <li><strong>Email/WhatsApp:</strong> configura SMTP_* y WHATSAPP_* en las variables de entorno del API.</li>
      <li><strong>Promover admin:</strong> <code>update perfiles set rol='admin' where email='…'</code> en SQL Editor.</li>
    </ul>
  </div>
{/if}
