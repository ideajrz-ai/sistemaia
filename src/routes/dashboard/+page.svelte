<script>
  import { onMount } from 'svelte';
  import { requireSession, apiFetch, getMyProfile } from '$lib/auth.js';
  import { supabase } from '$lib/supabase.js';
  import { goto } from '$app/navigation';

  const MODULOS = [
    ['panel', 'Panel'],
    ['encuesta', 'Encuesta'],
    ['sesiones', 'Sesiones'],
    ['archivos', 'Archivos'],
    ['citas', 'Citas'],
    ['qr', 'QR acceso'],
    ['geocercas', 'Geocercas'],
  ];

  let cargando = true;
  let perfil = null;
  let email = '';
  let form = { nombre: '', telefono: '', direccion: '', necesidad: '' };
  let guardando = false;
  let error = '';
  let exito = '';

  onMount(async () => {
    const session = await requireSession();
    if (!session) return;
    try {
      const data = await apiFetch('/api/me');
      perfil = data.perfil;
      email = data.user.email;
      if (perfil) {
        form = {
          nombre: perfil.nombre ?? '',
          telefono: perfil.telefono ?? '',
          direccion: perfil.direccion ?? '',
          necesidad: perfil.necesidad ?? '',
        };
      }
    } catch (e) {
      error = e.message;
    } finally {
      cargando = false;
    }
  });

  function moduloVisible(m) {
    const mods = perfil?.modulos_visibles;
    return !Array.isArray(mods) || mods.includes(m);
  }

  async function guardar() {
    error = '';
    exito = '';
    guardando = true;
    try {
      const data = await apiFetch('/api/me', { method: 'PATCH', body: JSON.stringify(form) });
      perfil = data.perfil;
      exito = 'Datos guardados correctamente.';
    } catch (e) {
      error = e.message;
    } finally {
      guardando = false;
    }
  }
</script>

<svelte:head><title>Mi panel · SistemaIA</title></svelte:head>

{#if cargando}
  <div class="tarjeta"><p class="tenue">Cargando…</p></div>
{:else if perfil}
  <div class="tarjeta">
    <h1>Hola, {perfil.nombre || email}</h1>
    <p class="tenue">Rol: {perfil.rol} · Miembro desde {new Date(perfil.created_at).toLocaleDateString('es')}</p>
  </div>

  {#if moduloVisible('panel')}
  <div class="tarjeta">
    <h2>Mis datos generales</h2>
    <div class="campo">
      <label for="d-email">Correo (no editable)</label>
      <input id="d-email" type="email" value={email} disabled />
    </div>
    <div class="campo">
      <label for="d-nombre">Nombre completo</label>
      <input id="d-nombre" type="text" bind:value={form.nombre} />
    </div>
    <div class="campo">
      <label for="d-tel">Teléfono / WhatsApp</label>
      <input id="d-tel" type="tel" bind:value={form.telefono} />
    </div>
    <div class="campo">
      <label for="d-dir">Dirección</label>
      <input id="d-dir" type="text" bind:value={form.direccion} />
    </div>
    <div class="campo">
      <label for="d-nec">Necesidad / servicio que solicito</label>
      <textarea id="d-nec" rows="3" bind:value={form.necesidad}></textarea>
    </div>
    {#if error}<p class="error">{error}</p>{/if}
    {#if exito}<p class="exito">{exito}</p>{/if}
    <button class="boton" on:click={guardar} disabled={guardando}>
      {guardando ? 'Guardando…' : 'Guardar cambios'}
    </button>
  </div>
  {/if}

  <div class="tarjeta">
    <h2>Mis módulos</h2>
    <div style="display:flex; gap:0.75rem; flex-wrap:wrap;">
      {#if moduloVisible('encuesta')}
        <a class="boton boton-secundario" href="/encuesta">Responder encuesta</a>
      {/if}
      {#if moduloVisible('sesiones')}
        <a class="boton boton-secundario" href="/sesiones">Mis sesiones</a>
      {/if}
      {#if moduloVisible('archivos')}
        <a class="boton boton-secundario" href="/archivos">Mis archivos</a>
      {/if}
      {#if moduloVisible('citas')}
        <a class="boton boton-secundario" href="/citas">Mis citas</a>
      {/if}
      {#if moduloVisible('qr')}
        <a class="boton boton-secundario" href="/qr">Mi QR de acceso</a>
      {/if}
      {#if moduloVisible('geocercas')}
        <a class="boton boton-secundario" href="/geocercas">Geocercas</a>
      {/if}
    </div>
  </div>
{:else}
  <div class="tarjeta"><p class="error">{error || 'No se pudo cargar el perfil.'}</p></div>
{/if}
