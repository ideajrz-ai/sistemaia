<script>
  import { onMount } from 'svelte';
  import { requireSession } from '$lib/auth.js';
  import { supabase } from '$lib/supabase.js';
  import { goto } from '$app/navigation';

  const MODULOS = [
    { clave: 'sesiones', titulo: 'Mis sesiones', desc: 'Da seguimiento a tus sesiones de consultoría: historial, notas y estado.', icono: '🗓️', href: '/sesiones' },
    { clave: 'archivos', titulo: 'Documentos', desc: 'Consulta y descarga los documentos e imágenes de tu expediente.', icono: '📁', href: '/archivos' },
    { clave: 'encuesta', titulo: 'Encuestas', desc: 'Responde o revisa tus encuestas de diagnóstico y recomendaciones.', icono: '📝', href: '/encuesta' },
    { clave: 'citas', titulo: 'Citas', desc: 'Agenda y consulta tus próximas citas con recordatorios.', icono: '📅', href: '/citas' },
    { clave: 'qr', titulo: 'QR de acceso', desc: 'Genera tu credencial QR de un solo día para entrar a la oficina.', icono: '🔳', href: '/qr' },
    { clave: 'geocercas', titulo: 'Geocercas', desc: 'Dibuja y administra zonas geográficas (círculos y polígonos) sobre un mapa.', icono: '🗺️', href: '/geocercas' },
    { clave: 'panel', titulo: 'Mi panel', desc: 'Actualiza tus datos generales y necesidades.', icono: '👤', href: '/dashboard' },
  ];

  const ETIQUETA_TIPO = { info: 'Información', aviso: 'Aviso', importante: 'Importante' };

  let cargando = true;
  let nombre = '';
  let modulosVisibles = null;
  let anuncios = [];
  let error = '';

  onMount(async () => {
    const session = await requireSession();
    if (!session) return;

    try {
      const { data: perfil } = await supabase
        .from('perfiles')
        .select('nombre, modulos_visibles')
        .eq('id', session.user.id)
        .single();
      nombre = perfil?.nombre || session.user.email || '';
      modulosVisibles = perfil?.modulos_visibles;

      const { data: lista } = await supabase
        .from('anuncios')
        .select('id, titulo, mensaje, tipo, created_at')
        .eq('activo', true)
        .order('created_at', { ascending: false })
        .limit(10);
      anuncios = lista || [];
    } catch (e) {
      error = e.message;
    } finally {
      cargando = false;
    }
  });

  function moduloVisible(clave) {
    return !Array.isArray(modulosVisibles) || modulosVisibles.includes(clave);
  }

  function elegir(modulo) {
    goto(modulo.href);
  }
</script>

<svelte:head><title>Bienvenida · SistemaIA</title></svelte:head>

{#if cargando}
  <div class="tarjeta"><p class="tenue">Cargando…</p></div>
{:else}
  <div class="bienvenida-hero">
    <img src="/logo-idea.jpg" alt="Idea Group" />
    <p class="tenue" style="letter-spacing:.15em; text-transform:uppercase; font-size:.8rem;">Idea Group · Consultoría</p>
    <h1>BIENVENIDO A TU ESPACIO</h1>
    {#if nombre}<p>Hola, <strong>{nombre}</strong>. ¿Qué deseas hacer hoy?</p>{/if}
  </div>

  {#if anuncios.length > 0}
    <div class="tarjeta">
      <h2>Anuncios</h2>
      {#each anuncios as a}
        <div class="anuncio tipo-{a.tipo}">
          <strong>{a.titulo}</strong>
          <span class="anuncio-tipo">{ETIQUETA_TIPO[a.tipo] || a.tipo}</span>
          <p class="tenue" style="margin:.35rem 0 0; white-space:pre-line;">{a.mensaje}</p>
          <p class="tenue" style="font-size:.75rem; margin:.35rem 0 0;">{new Date(a.created_at).toLocaleDateString('es')}</p>
        </div>
      {/each}
    </div>
  {/if}

  <div class="tarjeta">
    <h2>Elige una opción</h2>
    <p class="tenue">Selecciona el módulo al que quieres dar seguimiento:</p>
    <div class="menu-modulos">
      {#each MODULOS.filter(m => moduloVisible(m.clave)) as m}
        <button class="modulo-card" on:click={() => elegir(m)}>
          <span class="modulo-icono">{m.icono}</span>
          <strong>{m.titulo}</strong>
          <span class="tenue">{m.desc}</span>
        </button>
      {/each}
    </div>
  </div>

  {#if error}<p class="error">{error}</p>{/if}
{/if}

<style>
  .bienvenida-hero {
    text-align: center;
    padding: 3rem 1.5rem 2rem;
  }
  .bienvenida-hero img {
    width: 96px;
    height: 96px;
    border-radius: 50%;
    object-fit: cover;
    margin-bottom: 1rem;
  }
  .bienvenida-hero h1 {
    margin: 0.25rem 0 0.5rem;
    font-size: 2rem;
    letter-spacing: 0.05em;
    color: var(--color-primario);
  }

  .anuncio {
    border-left: 4px solid var(--color-borde);
    padding: 0.75rem 1rem;
    margin-bottom: 0.75rem;
    background: #101013;
    border-radius: 0 8px 8px 0;
  }
  .anuncio.tipo-aviso { border-left-color: #fbbf24; }
  .anuncio.tipo-importante { border-left-color: var(--color-error); }
  .anuncio-tipo {
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--color-tenue);
    border: 1px solid var(--color-borde);
    border-radius: 999px;
    padding: 0.1rem 0.5rem;
    margin-left: 0.5rem;
    vertical-align: middle;
  }

  .menu-modulos {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
    gap: 1rem;
    margin-top: 1rem;
  }
  .modulo-card {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 0.4rem;
    text-align: left;
    background: #101013;
    border: 1px solid var(--color-borde);
    border-radius: 12px;
    padding: 1rem 1.1rem;
    color: var(--color-texto);
    cursor: pointer;
    transition: border-color 0.15s, transform 0.15s;
    font-family: inherit;
  }
  .modulo-card:hover {
    border-color: var(--color-primario);
    transform: translateY(-2px);
  }
  .modulo-card strong { font-size: 1rem; }
  .modulo-icono { font-size: 1.6rem; }
</style>
