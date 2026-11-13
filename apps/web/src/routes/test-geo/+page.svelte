<script>
  let lat = '';
  let lng = '';
  let error = '';
  let loading = false;

  async function obtenerUbicacion() {
    error = '';
    loading = true;
    lat = '';
    lng = '';

    console.log('🔍 Iniciando prueba de geolocalización...');
    console.log('📍 navigator.geolocation existe:', !!navigator.geolocation);

    if (!navigator.geolocation) {
      error = '❌ Tu navegador no soporta geolocalización';
      loading = false;
      return;
    }

    try {
      console.log('⏳ Solicitando posición...');
      const position = await new Promise((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(
          resolve,
          reject,
          { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
        );
      });

      console.log('✅ Posición obtenida:', position);
      const { latitude, longitude, accuracy } = position.coords;
      lat = latitude.toFixed(6);
      lng = longitude.toFixed(6);
      console.log(`📍 Latitud: ${lat}, Longitud: ${lng}, Precisión: ${accuracy}m`);
    } catch (err) {
      console.error('❌ Error de geolocalización:', err);
      console.error('Código:', err.code, 'Mensaje:', err.message);

      if (err.code === 1) {
        error = '❌ Permiso denegado. Por favor, permite el acceso a tu ubicación en el navegador.';
      } else if (err.code === 2) {
        error = '❌ No se pudo determinar la ubicación. Verifica que el GPS esté activado.';
      } else if (err.code === 3) {
        error = '❌ Tiempo de espera agotado. Intenta nuevamente.';
      } else {
        error = `❌ Error desconocido: ${err.message}`;
      }
    } finally {
      loading = false;
    }
  }
</script>

<svelte:head><title>Test Geolocalización</title></svelte:head>

<div class="tarjeta">
  <h1>Test de Geolocalización</h1>
  <p class="tenue">Página simple para probar si la geolocalización funciona en tu navegador.</p>

  <button class="boton" on:click={obtenerUbicacion} disabled={loading}>
    {loading ? '⏳ Obteniendo ubicación...' : '📍 Obtener mi ubicación'}
  </button>

  {#if error}
    <p class="error" style="margin-top: 1rem;">{error}</p>
  {/if}

  {#if lat && lng}
    <div style="margin-top: 1rem; padding: 1rem; background: #101013; border-radius: 8px; border: 1px solid var(--color-borde);">
      <p><strong>✅ Ubicación obtenida:</strong></p>
      <p>Latitud: {lat}</p>
      <p>Longitud: {lng}</p>
    </div>
  {/if}

  <div style="margin-top: 2rem; padding: 1rem; background: rgba(74, 222, 128, 0.1); border-radius: 8px; border: 1px solid #4ade80;">
    <p class="exito" style="margin: 0;"><strong>ℹ️ Instrucciones:</strong></p>
    <ul style="margin: 0.5rem 0 0 1.5rem; color: var(--color-tenue);">
      <li>Abre la consola del navegador (F12 o Cmd+Option+I)</li>
      <li>Haz clic en "Obtener mi ubicación"</li>
      <li>Si el navegador te pide permiso, dale clic en "Permitir"</li>
      <li>Revisa los mensajes en la consola para ver el proceso detallado</li>
    </ul>
  </div>
</div>

<style>
  :global(.tarjeta) {
    background: var(--color-tarjeta);
    border: 1px solid var(--color-borde);
    border-radius: 12px;
    padding: 1.5rem;
    margin-bottom: 1rem;
  }
  :global(.boton) {
    display: inline-block;
    padding: 0.65rem 1.4rem;
    border: none;
    border-radius: 8px;
    background: var(--color-primario);
    color: var(--color-primario-texto);
    font-weight: 600;
    font-size: 1rem;
    cursor: pointer;
  }
  :global(.boton:hover) { filter: brightness(1.1); }
  :global(.boton:disabled) { opacity: 0.6; cursor: not-allowed; }
  :global(.error) { color: var(--color-error); }
  :global(.exito) { color: var(--color-exito); }
  :global(.tenue) { color: var(--color-tenue); }
</style>
