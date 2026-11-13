<script>
  import '../app.css';
  import { page } from '$app/stores';
  import { supabase } from '$lib/supabase.js';
  import { onMount } from 'svelte';

  let usuario = null;
  let perfil = null;

  onMount(() => {
    supabase.auth.getSession().then(({ data }) => {
      usuario = data.session?.user ?? null;
      cargarPerfil();
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_e, session) => {
      usuario = session?.user ?? null;
      cargarPerfil();
    });
    return () => sub.subscription.unsubscribe();
  });

  async function cargarPerfil() {
    if (!usuario) { perfil = null; return; }
    const { data } = await supabase
      .from('perfiles').select('rol, modulos_visibles').eq('id', usuario.id).single();
    perfil = data;
  }

  function moduloVisible(m) {
    const mods = perfil?.modulos_visibles;
    return !perfil || !Array.isArray(mods) || mods.includes(m);
  }

  async function cerrarSesion() {
    await supabase.auth.signOut();
    location.href = '/';
  }
</script>

<nav class="nav">
  <a class="marca" href="/"><img src="/logo-idea.jpg" alt="Idea Group" style="height:32px; width:32px; border-radius:50%; object-fit:cover; vertical-align:middle; margin-right:.5rem;" />SistemaIA · Consultoría</a>
  <span class="espacio"></span>
  {#if usuario}
    <a href="/bienvenida">Inicio</a>
    {#if moduloVisible('encuesta')}<a href="/encuesta">Encuesta</a>{/if}
    {#if moduloVisible('sesiones')}<a href="/sesiones">Sesiones</a>{/if}
    {#if moduloVisible('archivos')}<a href="/archivos">Archivos</a>{/if}
    {#if moduloVisible('citas')}<a href="/citas">Citas</a>{/if}
    {#if moduloVisible('qr')}<a href="/qr">QR</a>{/if}
    {#if moduloVisible('geocercas')}<a href="/geocercas">Geocercas</a>{/if}
    <a href="/test-geo">Test Geo</a>
    <a href="/dashboard">Mi panel</a>
    {#if perfil?.rol === 'admin'}<a href="/admin">Admin</a>{/if}
    <button class="boton boton-secundario" on:click={cerrarSesion}>Salir</button>
  {:else}
    <a href="/login">Entrar</a>
    <a class="boton" href="/registro">Crear cuenta</a>
  {/if}
</nav>

<main class="contenedor">
  <slot />
</main>
