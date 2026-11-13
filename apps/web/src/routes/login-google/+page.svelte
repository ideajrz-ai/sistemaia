<script>
  import { supabase } from '$lib/supabase.js';
  import { goto } from '$app/navigation';

  let usuario = null;
  let perfil = null;
  let cargando = false;
  let error = '';

  // Al cargar, revisa si ya hay sesion (p.ej. al volver del OAuth)
  async function cargarSesion() {
    const { data: { user } } = await supabase.auth.getUser();
    usuario = user;
    if (user) {
      const { data } = await supabase
        .from('perfiles')
        .select('*')
        .eq('id', user.id)
        .single();
      perfil = data;
    }
  }
  cargarSesion();

  async function entrarConGoogle() {
    error = '';
    cargando = true;
    const { error: err } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        // Supabase redirige aqui tras autenticar en Google
        redirectTo: `${window.location.origin}/login-google`,
      },
    });
    // Si hay error no redirige; si todo ok el navegador sale a Google
    cargando = false;
    if (err) error = err.message;
  }

  async function salir() {
    await supabase.auth.signOut();
    usuario = null;
    perfil = null;
    goto('/login-google');
  }
</script>

<svelte:head><title>Login Google · SistemaIA</title></svelte:head>

<div class="tarjeta" style="max-width:520px; margin:2rem auto;">
  <h1>Prueba · Login con Google</h1>
  <p class="tenue">
    Verifica que al iniciar sesion con Google se cree automaticamente
    un registro en <code>auth.users</code> y un perfil en <code>perfiles</code>.
  </p>

  {#if !usuario}
    {#if error}<p class="error">{error}</p>{/if}
    <button class="boton" on:click={entrarConGoogle} disabled={cargando}>
      {cargando ? 'Redirigiendo a Google…' : 'Entrar con Google'}
    </button>
    <p class="tenue" style="margin-top:1rem;">
      <a href="/login">Volver al login normal</a>
    </p>
  {:else}
    <div class="exito">Sesion iniciada correctamente.</div>

    <h2 style="margin-top:1rem;">Usuario (auth.users)</h2>
    <table style="width:100%; font-size:.9rem;"><tbody>
      <tr><td class="tenue">ID</td><td><code>{usuario.id}</code></td></tr>
      <tr><td class="tenue">Email</td><td>{usuario.email}</td></tr>
      <tr><td class="tenue">Nombre</td><td>{usuario.user_metadata?.full_name || usuario.user_metadata?.name || '—'}</td></tr>
      <tr><td class="tenue">Proveedor</td><td>{usuario.app_metadata?.provider || '—'}</td></tr>
      <tr><td class="tenue">Creado</td><td>{new Date(usuario.created_at).toLocaleString()}</td></tr>
    </tbody></table>

    <h2 style="margin-top:1rem;">Perfil (tabla perfiles)</h2>
    {#if perfil}
      <p class="exito">✓ Perfil encontrado en la base de datos</p>
      <table style="width:100%; font-size:.9rem;"><tbody></tbody>
        <tr><td class="tenue">Nombre</td><td>{perfil.nombre || '—'}</td></tr>
        <tr><td class="tenue">Telefono</td><td>{perfil.telefono || '—'}</td></tr>
        <tr><td class="tenue">Rol</td><td>{perfil.rol}</td></tr>
        <tr><td class="tenue">Modulos</td><td><code>{JSON.stringify(perfil.modulos_visibles)}</code></td></tr>
        <tr><td class="tenue">Creado</td><td>{new Date(perfil.created_at).toLocaleString()}</td></tr>
      </tbody></table>
    {:else}
      <p class="error">✗ No se encontro perfil. Revisa que hayas ejecutado setup_completo.sql (trigger handle_new_user).</p>
    {/if}

    <div style="margin-top:1rem; display:flex; gap:.5rem;">
      <button class="boton" on:click={salir}>Cerrar sesion</button>
      <a class="boton" href="/dashboard" style="text-decoration:none;">Ir al dashboard</a>
    </div>
  {/if}
</div>
