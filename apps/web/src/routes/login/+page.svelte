<script>
  import { supabase } from '$lib/supabase.js';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';

  let email = '';
  let password = '';
  let cargando = false;
  let cargandoGoogle = false;
  let error = '';

  onMount(async () => {
    // Si ya hay sesion (p.ej. al volver de Google), ir al inicio
    const { data: { session } } = await supabase.auth.getSession();
    if (session) goto('/bienvenida');
  });

  async function entrarConGoogle() {
    error = '';
    cargandoGoogle = true;
    const { error: err } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${window.location.origin}/login`,
      },
    });
    cargandoGoogle = false;
    if (err) error = err.message;
  }

  async function entrar() {
    error = '';
    cargando = true;
    const { error: err } = await supabase.auth.signInWithPassword({ email, password });
    cargando = false;
    if (err) {
      error = 'Credenciales incorrectas o cuenta no confirmada.';
      return;
    }
    goto('/bienvenida');
  }
</script>

<svelte:head><title>Entrar · SistemaIA</title></svelte:head>

<div class="tarjeta" style="max-width:420px; margin:2rem auto;">
  <h1>Iniciar sesión</h1>
  <form on:submit|preventDefault={entrar}>
    <div class="campo">
      <label for="email">Correo</label>
      <input id="email" type="email" bind:value={email} required autocomplete="email" />
    </div>
    <div class="campo">
      <label for="password">Contraseña</label>
      <input id="password" type="password" bind:value={password} required autocomplete="current-password" />
    </div>
    {#if error}<p class="error">{error}</p>{/if}
    <button class="boton" type="submit" disabled={cargando || cargandoGoogle}>
      {cargando ? 'Entrando…' : 'Entrar'}
    </button>
  </form>

  <div class="tenue" style="text-align:center; margin:1rem 0;">— o —</div>
  <button class="boton boton-secundario" on:click={entrarConGoogle} disabled={cargando || cargandoGoogle}>
    {cargandoGoogle ? 'Redirigiendo a Google…' : 'Entrar con Google'}
  </button>
  <p class="tenue" style="margin-top:1rem;">
    ¿No tienes cuenta? <a href="/registro">Regístrate</a>
  </p>
  <p class="tenue" style="margin-top:.5rem;">
    <a href="/login-google">Probar login con Google</a>
  </p>
</div>
