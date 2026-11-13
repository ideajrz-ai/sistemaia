<script>
  import { onMount } from 'svelte';
  import { requireSession } from '$lib/auth.js';
  import GeofenceMap from '$lib/components/GeofenceMap.svelte';
  import {
    nuevoId,
    aGeoJSON,
    importarGeocercas,
    puntoEnGeocerca,
    areaGeocerca,
    formatearArea,
    formatearDistancia,
    distanciaMetros,
    distanciaPuntoPoligono,
  } from '$lib/geocercas.js';

  const CLAVE = 'geocercas';

  let cargando = true;
  let geocercas = [];
  let error = '';
  let foco = null;
  let inputArchivo;
  let pruebaLat = '18.4861';
  let pruebaLng = '-69.9312';
  let resultadoPrueba = null;
  let obteniendoUbicacion = false;

  onMount(async () => {
    await requireSession();
    try {
      const raw = localStorage.getItem(CLAVE);
      if (raw) geocercas = JSON.parse(raw);
    } catch {
      error = 'No se pudieron cargar las geocercas guardadas.';
    } finally {
      cargando = false;
    }
  });

  function persistir() {
    try {
      localStorage.setItem(CLAVE, JSON.stringify(geocercas));
    } catch {
      /* almacenamiento lleno o no disponible */
    }
  }

  function alCambiar(ev) {
    geocercas = ev.detail.geocercas;
    persistir();
  }

  function renombrar(g, nombre) {
    geocercas = geocercas.map((x) => (x.id === g.id ? { ...x, nombre } : x));
    persistir();
  }

  function eliminar(g) {
    if (!confirm(`¿Eliminar "${g.nombre}"?`)) return;
    geocercas = geocercas.filter((x) => x.id !== g.id);
    persistir();
  }

  function eliminarTodas() {
    if (!geocercas.length) return;
    if (!confirm(`¿Eliminar las ${geocercas.length} geocercas?`)) return;
    geocercas = [];
    persistir();
  }

  function enfocar(g) {
    foco = { id: g.id, ts: Date.now() };
  }

  function exportar() {
    const datos = {
      app: 'sistema-ia',
      tipo: 'geocercas',
      version: 1,
      exportado: new Date().toISOString(),
      geocercas: geocercas.map(aGeoJSON),
    };
    const blob = new Blob([JSON.stringify(datos, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `geocercas-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
  }

  async function importar(ev) {
    const archivo = ev.target.files?.[0];
    ev.target.value = '';
    if (!archivo) return;
    error = '';
    try {
      const json = JSON.parse(await archivo.text());
      const nuevas = importarGeocercas(json).map((g) => ({ ...g, id: nuevoId() }));
      if (!nuevas.length) {
        error = 'El archivo no contiene geocercas válidas.';
        return;
      }
      geocercas = [...geocercas, ...nuevas];
      persistir();
    } catch {
      error = 'No se pudo leer el archivo. Debe ser un JSON de geocercas.';
    }
  }

  function probarPunto(lat, lng) {
    if (geocercas.length === 0) {
      resultadoPrueba = { dentro: [], fuera: [] };
      return;
    }
    const dentro = geocercas.filter((g) => puntoEnGeocerca(g, lat, lng));
    resultadoPrueba = {
      dentro,
      fuera: geocercas.filter((g) => !puntoEnGeocerca(g, lat, lng)),
    };
  }

  function comprobar() {
    error = '';
    console.log('comprobar() - pruebaLat:', pruebaLat, 'pruebaLng:', pruebaLng);
    const lat = Number(pruebaLat);
    const lng = Number(pruebaLng);
    console.log('comprobar() - lat:', lat, 'lng:', lng);

    if (pruebaLat === '' || pruebaLng === '' || Number.isNaN(lat) || Number.isNaN(lng)) {
      error = 'Ingresa una latitud y longitud válidas.';
      console.error('Validación falló - valores inválidos');
      return;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      error = 'Latitud debe estar entre -90 y 90; longitud entre -180 y 180.';
      console.error('Validación falló - coordenadas fuera de rango');
      return;
    }
    console.log('Validación exitosa, probando punto');
    probarPunto(lat, lng);
  }

  async function usarMiUbicacion() {
    if (obteniendoUbicacion) return;
    error = '';
    obteniendoUbicacion = true;
    console.log('Iniciando solicitud de ubicación...');

    if (!navigator.geolocation) {
      error = 'Tu navegador no soporta geolocalización.';
      console.error('Geolocalización no soportada');
      obteniendoUbicacion = false;
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
      const { latitude, longitude } = position.coords;
      console.log('Latitud:', latitude, 'Longitud:', longitude);

      pruebaLat = latitude.toFixed(6);
      pruebaLng = longitude.toFixed(6);
      console.log('Valores asignados - pruebaLat:', pruebaLat, 'pruebaLng:', pruebaLng);

      probarPunto(latitude, longitude);
    } catch (err) {
      console.error('❌ Error de geolocalización:', err);
      console.error('Código:', err.code, 'Mensaje:', err.message);

      let mensaje = 'No se pudo obtener tu ubicación.';
      if (err.code === 1) {
        mensaje = 'Permiso de ubicación denegado. Por favor, permite el acceso a tu ubicación en el navegador.';
      } else if (err.code === 2) {
        mensaje = 'No se pudo determinar tu ubicación. Verifica que el GPS esté activado.';
      } else if (err.code === 3) {
        mensaje = 'Tiempo de espera agotado al obtener la ubicación.';
      }
      error = mensaje;
    } finally {
      obteniendoUbicacion = false;
    }
  }

  function distanciaAGeocerca(g, lat, lng) {
    if (g.tipo === 'circulo') {
      const d = distanciaMetros([lat, lng], g.centro);
      return d <= g.radio_m ? 0 : d - g.radio_m;
    }
    // Para polígonos: distancia al borde más cercano.
    return distanciaPuntoPoligono(lat, lng, g.coordenadas || []);
  }

  function tipoLabel(g) {
    return g.tipo === 'circulo' ? 'Círculo' : 'Polígono';
  }
</script>

<svelte:head><title>Geocercas · SistemaIA</title></svelte:head>

{#if cargando}
  <div class="tarjeta"><p class="tenue">Cargando…</p></div>
{:else}
  <div class="tarjeta">
    <h1>Geocercas</h1>
    <p class="tenue">
      Dibuja zonas circulares o poligonales sobre el mapa. Usa la barra de herramientas
      (arriba a la derecha) para dibujar; con el lápiz editas vértices y con la papelera
      eliminas formas. Las geocercas se guardan en este navegador.
    </p>
    {#if error}<p class="error">{error}</p>{/if}
  </div>

  <div class="tarjeta" style="padding:0.75rem;">
    <GeofenceMap {geocercas} on:change={alCambiar} {foco} alto="480px" />
  </div>

  <div class="tarjeta">
    <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:0.5rem;">
      <h2 style="margin:0;">Mis geocercas ({geocercas.length})</h2>
      <div style="display:flex; gap:0.5rem; flex-wrap:wrap;">
        <button class="boton boton-secundario" style="padding:0.4rem 0.8rem;" on:click={exportar} disabled={!geocercas.length}>
          Exportar JSON
        </button>
        <button class="boton boton-secundario" style="padding:0.4rem 0.8rem;" on:click={() => inputArchivo.click()}>
          Importar
        </button>
        <button class="boton boton-secundario" style="padding:0.4rem 0.8rem;" on:click={eliminarTodas} disabled={!geocercas.length}>
          Borrar todas
        </button>
        <input bind:this={inputArchivo} type="file" accept="application/json,.geojson" style="display:none;" on:change={importar} />
      </div>
    </div>

    {#if geocercas.length === 0}
      <p class="tenue">Aún no hay geocercas. Dibuja un círculo, polígono o rectángulo en el mapa.</p>
    {:else}
      <table class="tabla" style="margin-top:0.75rem;">
        <thead>
          <tr><th>Nombre</th><th>Tipo</th><th>Área aprox.</th><th></th></tr>
        </thead>
        <tbody>
          {#each geocercas as g (g.id)}
            <tr>
              <td style="min-width:180px;">
                <input
                  type="text"
                  value={g.nombre}
                  on:change={(e) => renombrar(g, e.target.value)}
                  style="width:100%; padding:0.35rem 0.5rem; border-radius:6px; border:1px solid var(--color-borde); background:#101013; color:var(--color-texto);"
                />
              </td>
              <td>{tipoLabel(g)}</td>
              <td>{formatearArea(areaGeocerca(g))}</td>
              <td style="white-space:nowrap;">
                <button class="boton boton-secundario" style="padding:0.3rem 0.6rem; margin-right:0.4rem;" on:click={() => enfocar(g)}>Ver</button>
                <button class="boton boton-secundario" style="padding:0.3rem 0.6rem;" on:click={() => eliminar(g)}>Borrar</button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>

  <div class="tarjeta">
    <h2>Comprobar un punto</h2>
    <p class="tenue">Verifica si una coordenada está dentro de alguna geocerca.</p>
    <div style="display:flex; gap:1rem; flex-wrap:wrap; align-items:end;">
      <div class="campo" style="flex:1; min-width:160px; margin-bottom:0;">
        <label for="prueba-lat">Latitud</label>
        <input id="prueba-lat" type="number" step="any" bind:value={pruebaLat} placeholder="18.4861" />
      </div>
      <div class="campo" style="flex:1; min-width:160px; margin-bottom:0;">
        <label for="prueba-lng">Longitud</label>
        <input id="prueba-lng" type="number" step="any" bind:value={pruebaLng} placeholder="-69.9312" />
      </div>
      <button class="boton" on:click={comprobar}>Comprobar</button>
      <button class="boton boton-secundario" on:click={usarMiUbicacion} disabled={obteniendoUbicacion}>
        {obteniendoUbicacion ? 'Obteniendo...' : 'Mi ubicación'}
      </button>
    </div>

    {#if resultadoPrueba}
      <div style="margin-top:1rem;">
        {#if resultadoPrueba.dentro.length}
          <p class="exito">
            Dentro de: {resultadoPrueba.dentro.map((g) => g.nombre).join(', ')}
          </p>
        {:else}
          <p class="tenue">El punto no está dentro de ninguna geocerca.</p>
        {/if}
        {#each resultadoPrueba.fuera as g}
          <p class="tenue" style="font-size:0.85rem;">
            {g.nombre}: a {formatearDistancia(distanciaAGeocerca(g, Number(pruebaLat), Number(pruebaLng)))} del borde
          </p>
        {/each}
      </div>
    {/if}
  </div>
{/if}
