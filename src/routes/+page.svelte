<script>
  import { supabase } from '$lib/supabase.js';

  let cargandoGoogle = false;
  let error = '';

  async function entrarConGoogle() {
    error = '';
    cargandoGoogle = true;
    const { error: err } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        // Tras autenticar en Google vuelve a /login, que redirige a /bienvenida
        redirectTo: `${window.location.origin}/login`,
      },
    });
    cargandoGoogle = false;
    if (err) error = err.message;
  }
</script>

<svelte:head>
  <title>SistemaIA · Consultoría</title>
</svelte:head>

<div class="tarjeta" style="text-align:center; padding:3rem 1.5rem;">
  <img src="/logo-idea.jpg" alt="Idea Group" style="width:96px; height:96px; border-radius:50%; object-fit:cover; margin-bottom:1rem;" />
  <h1>Diagnóstico de necesidades para consultoría</h1>
  <p class="tenue">
    Plataforma para gestionar clientes, encuestas de diagnóstico, sesiones,
    documentos, citas y recordatorios.
  </p>
  <div style="margin-top:1.5rem; display:flex; gap:1rem; justify-content:center; flex-wrap:wrap;">
    <a class="boton" href="/registro">Registrarse</a>
    <a class="boton boton-secundario" href="/login">Iniciar sesión</a>
  </div>
  <div style="margin-top:1rem;">
    <button class="boton boton-google" on:click={entrarConGoogle} disabled={cargandoGoogle}>
      <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true">
        <path fill="#4285F4" d="M23.5 12.27c0-.85-.08-1.67-.22-2.45H12v4.64h6.45a5.52 5.52 0 0 1-2.39 3.62v3h3.87c2.26-2.09 3.57-5.17 3.57-8.81z"/>
        <path fill="#34A853" d="M12 24c3.24 0 5.95-1.07 7.93-2.91l-3.87-3c-1.07.72-2.44 1.15-4.06 1.15-3.13 0-5.78-2.11-6.73-4.96H1.29v3.09A12 12 0 0 0 12 24z"/>
        <path fill="#FBBC05" d="M5.27 14.28A7.2 7.2 0 0 1 4.89 12c0-.79.14-1.56.38-2.28V6.63H1.29a12 12 0 0 0 0 10.74l3.98-3.09z"/>
        <path fill="#EA4335" d="M12 4.77c1.76 0 3.35.61 4.6 1.8l3.42-3.42A11.98 11.98 0 0 0 12 0 12 12 0 0 0 1.29 6.63l3.98 3.09C6.22 6.88 8.87 4.77 12 4.77z"/>
      </svg>
      {cargandoGoogle ? 'Redirigiendo a Google…' : 'Registrarse con Google'}
    </button>
  </div>
  {#if error}<p class="error" style="text-align:center;">{error}</p>{/if}
</div>

<div class="tarjeta">
  <h2>Módulos del sistema</h2>
  <ul class="tenue">
    <li><strong>Clientes:</strong> datos generales, necesidades y expediente.</li>
    <li><strong>Encuesta dinámica:</strong> preguntas editables que generan diagnóstico y recomendaciones.</li>
    <li><strong>Sesiones y archivos:</strong> documentos e imágenes por cliente.</li>
    <li><strong>Citas:</strong> calendario con recordatorios por correo/WhatsApp.</li>
    <li><strong>Acceso QR:</strong> credencial de un solo día para entrar a la oficina.</li>
  </ul>
  <p class="tenue">Etapa actual: autenticación y estructura base. El resto se implementa por etapas.</p>
</div>
