<script>
  import { onMount } from 'svelte';
  import { requireSession, apiFetch } from '$lib/auth.js';

  const MODULOS = [
    ['panel', 'Panel'],
    ['encuesta', 'Encuesta'],
    ['sesiones', 'Sesiones'],
    ['archivos', 'Archivos'],
    ['citas', 'Citas'],
    ['qr', 'QR acceso'],
    ['geocercas', 'Geocercas'],
  ];
  const TODOS = MODULOS.map(([k]) => k);

  let cargando = true;
  let esAdmin = false;
  let clientes = [];
  let error = '';
  let aviso = '';
  let editando = null;   // cliente en edicion
  let guardando = false;

  onMount(async () => {
    const session = await requireSession();
    if (!session) return;
    try {
      const me = await apiFetch('/api/me');
      esAdmin = me.perfil?.rol === 'admin';
      if (!esAdmin) {
        error = 'Solo administradores.';
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
    const data = await apiFetch('/api/admin/clientes');
    clientes = data.clientes;
  }

  function toggleModulo(cliente, modulo) {
    const mods = Array.isArray(cliente.modulos_visibles) ? [...cliente.modulos_visibles] : [...TODOS];
    const i = mods.indexOf(modulo);
    if (i >= 0) mods.splice(i, 1); else mods.push(modulo);
    cliente.modulos_visibles = mods;
    clientes = clientes; // reactividad
  }

  function todosLosModulos(cliente, valor) {
    cliente.modulos_visibles = valor ? [...TODOS] : [];
    clientes = clientes;
  }

  async function guardar(cliente) {
    error = '';
    aviso = '';
    guardando = true;
    try {
      await apiFetch(`/api/admin/clientes/${cliente.id}`, {
        method: 'PATCH',
        body: JSON.stringify({
          modulos_visibles: cliente.modulos_visibles,
          necesidad: cliente.necesidad,
        }),
      });
      aviso = `Visibilidad actualizada para ${cliente.nombre || cliente.email}.`;
      editando = null;
    } catch (e) {
      error = e.message;
    } finally {
      guardando = false;
    }
  }

  async function verExpediente(cliente) {
    try {
      const data = await apiFetch(`/api/admin/clientes/${cliente.id}`);
      cliente._exp = data;
      cliente._verExp = !cliente._verExp;
      clientes = clientes;
    } catch (e) {
      error = e.message;
    }
  }
</script>

<svelte:head><title>Clientes · Admin</title></svelte:head>

{#if cargando}
  <div class="tarjeta"><p class="tenue">Cargando…</p></div>
{:else if !esAdmin}
  <div class="tarjeta"><p class="error">{error}</p></div>
{:else}
  <div class="tarjeta">
    <h1>Clientes y visibilidad de módulos</h1>
    <p class="tenue">Decide qué ve cada cliente en su portal.</p>
    {#if error}<p class="error">{error}</p>{/if}
    {#if aviso}<p class="exito">{aviso}</p>{/if}
  </div>

  {#each clientes as c}
    <div class="tarjeta">
      <div style="display:flex; justify-content:space-between; align-items:center; gap:1rem; flex-wrap:wrap;">
        <div>
          <strong>{c.nombre || 'Sin nombre'}</strong>
          <div class="tenue" style="font-size:0.85rem;">{c.email} · {c.telefono || 'sin teléfono'}</div>
          {#if c.necesidad}<div class="tenue" style="font-size:0.85rem;">Necesidad: {c.necesidad}</div>{/if}
        </div>
        <div style="display:flex; gap:0.5rem;">
          <button class="boton boton-secundario" style="padding:0.4rem 0.8rem;" on:click={() => verExpediente(c)}>
            {c._verExp ? 'Ocultar' : 'Expediente'}
          </button>
          <button class="boton boton-secundario" style="padding:0.4rem 0.8rem;" on:click={() => (editando = editando === c.id ? null : c.id)}>
            {editando === c.id ? 'Cerrar' : 'Módulos'}
          </button>
        </div>
      </div>

      {#if editando === c.id}
        <div style="margin-top:1rem; border-top:1px solid var(--color-borde); padding-top:1rem;">
          <div style="display:flex; gap:1rem; flex-wrap:wrap; margin-bottom:0.75rem;">
            {#each MODULOS as [key, label]}
              <label style="display:flex; gap:0.4rem; align-items:center;">
                <input type="checkbox"
                  checked={Array.isArray(c.modulos_visibles) && c.modulos_visibles.includes(key)}
                  on:change={() => toggleModulo(c, key)} />
                {label}
              </label>
            {/each}
          </div>
          <div class="campo" style="max-width:480px;">
            <label>Necesidad del cliente</label>
            <textarea rows="2" bind:value={c.necesidad}></textarea>
          </div>
          <div style="display:flex; gap:0.5rem;">
            <button class="boton" style="padding:0.4rem 1rem;" on:click={() => guardar(c)} disabled={guardando}>Guardar</button>
            <button class="boton boton-secundario" style="padding:0.4rem 1rem;" on:click={() => todosLosModulos(c, true)}>Ver todo</button>
            <button class="boton boton-secundario" style="padding:0.4rem 1rem;" on:click={() => todosLosModulos(c, false)}>Ocultar todo</button>
          </div>
        </div>
      {/if}

      {#if c._verExp && c._exp}
        <div style="margin-top:1rem; border-top:1px solid var(--color-borde); padding-top:1rem;">
          <p class="tenue">
            Encuestas: {c._exp.encuestas.length} · Sesiones: {c._exp.sesiones.length} ·
            Citas: {c._exp.citas.length} · Archivos: {c._exp.archivos.length}
          </p>
          {#if c._exp.encuestas.length}
            <h4>Última encuesta</h4>
            <p style="white-space:pre-line; font-size:0.9rem;">{c._exp.encuestas[0].diagnostico || 'Sin diagnóstico aún.'}</p>
          {/if}
          {#if c._exp.citas.length}
            <h4>Citas</h4>
            <ul class="tenue">
              {#each c._exp.citas as cita}
                <li>{new Date(cita.fecha_inicio).toLocaleString('es')} — {cita.titulo}</li>
              {/each}
            </ul>
          {/if}
        </div>
      {/if}
    </div>
  {/each}

  {#if clientes.length === 0}
    <div class="tarjeta"><p class="tenue">No hay clientes registrados.</p></div>
  {/if}
{/if}
