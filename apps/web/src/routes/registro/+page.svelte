<script>
  import { supabase } from '$lib/supabase.js';
  import { goto } from '$app/navigation';

  let nombre = '';
  let email = '';
  let telefono = '';
  let direccion = '';
  let password = '';
  let confirmacion = '';
  let cargando = false;
  let error = '';
  let aviso = '';

  async function registrarse() {
    error = '';
    if (password !== confirmacion) {
      error = 'Las contraseñas no coinciden.';
      return;
    }
    if (password.length < 8) {
      error = 'La contraseña debe tener al menos 8 caracteres.';
      return;
    }
    cargando = true;
    const { data, error: err } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { nombre, telefono, direccion },
      },
    });
    cargando = false;
    if (err) {
      error = err.message;
      return;
    }
    if (data.session) {
      goto('/dashboard');
    } else {
      aviso = 'Revisa tu correo para confirmar la cuenta y luego inicia sesión.';
    }
  }
</script>

<svelte:head><title>Registro · SistemaIA</title></svelte:head>

<div class="tarjeta" style="max-width:480px; margin:2rem auto;">
  <h1>Crear cuenta de cliente</h1>
  <form on:submit|preventDefault={registrarse}>
    <div class="campo">
      <label for="nombre">Nombre completo</label>
      <input id="nombre" type="text" bind:value={nombre} required />
    </div>
    <div class="campo">
      <label for="email">Correo</label>
      <input id="email" type="email" bind:value={email} required autocomplete="email" />
    </div>
    <div class="campo">
      <label for="telefono">Teléfono / WhatsApp</label>
      <input id="telefono" type="tel" bind:value={telefono} />
    </div>
    <div class="campo">
      <label for="direccion">Dirección</label>
      <input id="direccion" type="text" bind:value={direccion} />
    </div>
    <div class="campo">
      <label for="password">Contraseña (mín. 8 caracteres)</label>
      <input id="password" type="password" bind:value={password} required minlength="8" autocomplete="new-password" />
    </div>
    <div class="campo">
      <label for="confirmacion">Confirmar contraseña</label>
      <input id="confirmacion" type="password" bind:value={confirmacion} required minlength="8" autocomplete="new-password" />
    </div>
    {#if error}<p class="error">{error}</p>{/if}
    {#if aviso}<p class="exito">{aviso}</p>{/if}
    <button class="boton" type="submit" disabled={cargando}>
      {cargando ? 'Registrando…' : 'Registrarme'}
    </button>
  </form>
</div>
