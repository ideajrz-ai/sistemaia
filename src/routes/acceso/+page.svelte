<script>
  import { onMount } from 'svelte';
  import { page } from '$app/stores';

  let estado = 'verificando'; // verificando | valido | invalido
  let nombre = '';
  let motivo = '';

  onMount(async () => {
    const token = $page.url.searchParams.get('token');
    if (!token) {
      estado = 'invalido';
      motivo = 'Falta el token en la URL.';
      return;
    }
    try {
      const res = await fetch(`/api/qr/validar?token=${encodeURIComponent(token)}`);
      const data = await res.json();
      if (data.valido) {
        estado = 'valido';
        nombre = data.nombre;
      } else {
        estado = 'invalido';
        motivo = data.motivo || 'QR no válido.';
      }
    } catch {
      estado = 'invalido';
      motivo = 'No se pudo contactar al servidor.';
    }
  });
</script>

<svelte:head><title>Validación de acceso · SistemaIA</title></svelte:head>

<div class="tarjeta" style="max-width:480px; margin:3rem auto; text-align:center;">
  {#if estado === 'verificando'}
    <h1>Verificando QR…</h1>
    <p class="tenue">Un momento.</p>
  {:else if estado === 'valido'}
    <h1 style="color:var(--color-exito);">Acceso autorizado</h1>
    <p>Bienvenido/a, <strong>{nombre}</strong>.</p>
    <p class="tenue">Puedes pasar a recepción.</p>
  {:else}
    <h1 style="color:var(--color-error);">Acceso denegado</h1>
    <p>{motivo}</p>
    <p class="tenue">Genera un nuevo QR desde tu panel si es el día de tu cita.</p>
  {/if}
</div>
