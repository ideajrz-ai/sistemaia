<script>
  import { onMount, onDestroy, createEventDispatcher } from 'svelte';
  import { capaAGeocerca, geocercaACapa, nuevoId, colorAleatorio } from '$lib/geocercas.js';

  // Módulo independiente de geocercas sobre Leaflet.
  // Props:
  //   geocercas : array de geocercas (ver lib/geocercas.js)
  //   center    : [lat, lng] inicial del mapa
  //   zoom      : zoom inicial
  //   editable  : muestra las herramientas de dibujo/edición/borrado
  //   alto      : alto del mapa (CSS)
  //   foco      : { id } para centrar el mapa en una geocerca
  // Eventos:
  //   change -> { geocercas } cada vez que cambian las geocercas dibujadas
  export let geocercas = [];
  export let center = [18.4861, -69.9312];
  export let zoom = 12;
  export let editable = true;
  export let alto = '460px';
  export let foco = null;
  let dibujandoCirculo = false;
  let dibujandoPoligono = false;

  const dispatch = createEventDispatcher();

  let contenedor;
  let L = null; // leaflet solo existe en el navegador
  let mapa = null;
  let fg = null;
  let listo = false;
  let emitido = null;
  let ultimoFoco = null;
  let capas = new Map(); // id de geocerca -> capa Leaflet
  let marcadorUsuario = null;
  let circuloPrecision = null;
  let ubicacionCargada = false;

  onMount(async () => {
    // Imports dinámicos: leaflet requiere window/document, no puede evaluarse en SSR.
    L = (await import('$lib/leaflet-core.js')).default;
    await import('$lib/leaflet-draw.js');

    mapa = L.map(contenedor).setView(center, zoom);
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    }).addTo(mapa);

    fg = L.featureGroup().addTo(mapa);



    mapa.addControl(
      new L.Control.extend({
        options: { position: 'topright' },
        onAdd() {
          const div = L.DomUtil.create('div', 'leaflet-bar');
          const a = L.DomUtil.create('a', '', div);
          a.href = '#';
          a.title = 'Centrar en mi ubicación';
          a.setAttribute('role', 'button');
          a.innerHTML = '◎';
          L.DomEvent.disableClickPropagation(div);
          L.DomEvent.on(a, 'click', (ev) => {
            L.DomEvent.preventDefault(ev);
            L.DomEvent.stopPropagation(ev);
            solicitarUbicacion();
          });
          return div;
        },
      })()
    );

    reconstruir();
    emitido = geocercas;
    listo = true;
    setTimeout(() => mapa.invalidateSize(), 60);

    // Solicitar ubicación automáticamente al cargar
    solicitarUbicacion();
  });

  onDestroy(() => {
    if (mapa) mapa.remove();
    mapa = null;
  });

  // Cuando la prop cambia desde afuera (importar, borrar todo, etc.) se redibuja.
  $: if (listo && geocercas !== emitido) {
    reconstruir();
    emitido = geocercas;
  }

  // Cuando cambia `foco` se vuela hasta esa geocerca.
  $: if (listo && foco && foco !== ultimoFoco) {
    ultimoFoco = foco;
    const g = (geocercas || []).find((x) => x.id === foco.id);
    if (g) {
      const bounds =
        g.tipo === 'circulo'
          ? L.circle(g.centro, { radius: g.radio_m }).getBounds()
          : L.latLngBounds(g.coordenadas.map(([lat, lng]) => [lat, lng]));
      mapa.flyToBounds(bounds.pad(0.3));
    }
  }

  function reconstruir() {
    if (!fg) return;
    fg.clearLayers();
    capas = new Map();
    for (const g of geocercas || []) {
      const capa = geocercaACapa(g, L);
      capa._gid = g.id;
      fg.addLayer(capa);
      capas.set(g.id, capa);
    }
  }

  async function solicitarUbicacion() {
    console.log('GeofenceMap: solicitando ubicación...');
    if (!navigator.geolocation) {
      console.error('GeofenceMap: geolocalización no soportada');
      return;
    }
    if (!mapa) {
      console.error('GeofenceMap: mapa no inicializado');
      return;
    }

    try {
      console.log('GeofenceMap: ⏳ Solicitando posición...');
      const position = await new Promise((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(
          resolve,
          reject,
          { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
        );
      });

      console.log('GeofenceMap: ✅ Ubicación obtenida:', position);
      const { latitude: lat, longitude: lng, accuracy } = position.coords;
      const punto = [lat, lng];
      console.log('GeofenceMap: punto:', punto, 'precisión:', accuracy);

      if (!marcadorUsuario) {
        marcadorUsuario = L.marker(punto, { title: 'Tu ubicación' }).addTo(mapa);
        circuloPrecision = L.circle(punto, {
          radius: accuracy || 0,
          color: '#3b82f6',
          weight: 1,
          fillOpacity: 0.08,
        }).addTo(mapa);
        console.log('GeofenceMap: marcador creado');
      } else {
        marcadorUsuario.setLatLng(punto);
        circuloPrecision.setLatLng(punto).setRadius(accuracy || 0);
        console.log('GeofenceMap: marcador actualizado');
      }

      // Centrar el mapa en la ubicación del usuario con zoom adecuado
      mapa.setView(punto, 15, { animate: true, duration: 1.5 });
      ubicacionCargada = true;
      console.log('GeofenceMap: mapa centrado en ubicación');
    } catch (err) {
      console.error('GeofenceMap: ❌ Error de geolocalización:', err);
      console.error('GeofenceMap: Código:', err.code, 'Mensaje:', err.message);
      // Si falla la geolocalización, mantener la vista por defecto
    }
  }

  function emitir(nueva) {
    geocercas = nueva;
    emitido = nueva;
    dispatch('change', { geocercas: nueva });
  }

  function dibujarCirculo() {
    console.log('Iniciando dibujo de círculo');
    dibujandoCirculo = true;
    mapa.getContainer().style.cursor = 'crosshair';
    let centro = null;
    let circuloTemp = null;

    const onClick = (e) => {
      if (!centro) {
        centro = e.latlng;
        circuloTemp = L.circle(centro, { radius: 100, color: '#f97316', weight: 2, fillOpacity: 0.15 }).addTo(mapa);
        console.log('Centro del círculo:', centro);
      } else {
        const radio = mapa.distance(centro, e.latlng);
        circuloTemp.setRadius(radio);
        console.log('Radio del círculo:', radio);

        // Crear la geocerca
        const g = {
          id: nuevoId(),
          nombre: `Círculo ${geocercas.length + 1}`,
          color: colorAleatorio(geocercas.map((x) => x.color)),
          tipo: 'circulo',
          centro: [centro.lat, centro.lng],
          radio_m: radio,
          created_at: new Date().toISOString(),
        };

        fg.addLayer(circuloTemp);
        circuloTemp.setStyle({ color: g.color });
        circuloTemp._gid = g.id;
        capas.set(g.id, circuloTemp);
        emitir([...geocercas, g]);

        // Limpiar
        limpiarDibujo();
      }
    };

    const onMove = (e) => {
      if (centro && circuloTemp) {
        const radio = mapa.distance(centro, e.latlng);
        circuloTemp.setRadius(radio);
      }
    };

    mapa.on('click', onClick);
    mapa.on('mousemove', onMove);
  }

  function dibujarPoligono() {
    console.log('Iniciando dibujo de polígono');
    dibujandoPoligono = true;
    mapa.getContainer().style.cursor = 'crosshair';
    const puntos = [];
    let lineaTemp = null;
    let puntosMarcadores = [];

    const onClick = (e) => {
      puntos.push(e.latlng);
      console.log('Punto agregado:', e.latlng);

      // Agregar marcador temporal
      const marcador = L.circleMarker(e.latlng, { radius: 5, color: '#f97316' }).addTo(mapa);
      puntosMarcadores.push(marcador);

      if (puntos.length === 1) {
        // Primer punto
      } else if (puntos.length === 2) {
        // Segundo punto - crear línea
        lineaTemp = L.polyline(puntos, { color: '#f97316', weight: 2 }).addTo(mapa);
      } else {
        // Actualizar línea
        lineaTemp.setLatLngs(puntos);
      }
    };

    const onDblClick = (e) => {
      if (puntos.length >= 3) {
        console.log('Polígono completado con', puntos.length, 'puntos');

        // Cerrar el polígono
        const poligono = L.polygon(puntos, { color: '#f97316', weight: 2, fillOpacity: 0.15 }).addTo(mapa);

        // Crear la geocerca
        const g = {
          id: nuevoId(),
          nombre: `Polígono ${geocercas.length + 1}`,
          color: colorAleatorio(geocercas.map((x) => x.color)),
          tipo: 'poligono',
          coordenadas: puntos.map((p) => [p.lat, p.lng]),
          created_at: new Date().toISOString(),
        };

        // Limpiar temporales
        if (lineaTemp) mapa.removeLayer(lineaTemp);
        puntosMarcadores.forEach((m) => mapa.removeLayer(m));

        poligono.setStyle({ color: g.color });
        poligono._gid = g.id;
        fg.addLayer(poligono);
        capas.set(g.id, poligono);
        emitir([...geocercas, g]);
      }

      limpiarDibujo();
    };

    mapa.on('click', onClick);
    mapa.on('dblclick', onDblClick);
  }

  function limpiarDibujo() {
    mapa.off('click');
    mapa.off('mousemove');
    mapa.off('dblclick');
    mapa.getContainer().style.cursor = '';
    dibujandoCirculo = false;
    dibujandoPoligono = false;
  }

  function cancelarDibujo() {
    limpiarDibujo();
  }

  // Función para eliminar una geocerca del mapa
  export function eliminarGeocerca(id) {
    const capa = capas.get(id);
    if (capa) {
      fg.removeLayer(capa);
      capas.delete(id);
      emitir(geocercas.filter((g) => g.id !== id));
    }
  }
</script>

<div style="display:flex; gap:0.5rem; margin-bottom:0.5rem;">
  {#if editable}
    <button
      class="boton"
      on:click={dibujarCirculo}
      disabled={dibujandoCirculo || dibujandoPoligono}
      style="padding:0.5rem 1rem;"
    >
      {dibujandoCirculo ? 'Dibujando círculo...' : '⭕ Círculo'}
    </button>
    <button
      class="boton"
      on:click={dibujarPoligono}
      disabled={dibujandoCirculo || dibujandoPoligono}
      style="padding:0.5rem 1rem;"
    >
      {dibujandoPoligono ? 'Dibujando polígono...' : '⬡ Polígono'}
    </button>
    {#if dibujandoCirculo || dibujandoPoligono}
      <button class="boton boton-secundario" on:click={cancelarDibujo} style="padding:0.5rem 1rem;">
        Cancelar
      </button>
    {/if}
  {/if}
</div>

<div class="mapa" bind:this={contenedor} style:height={alto}></div>

<style>
  .mapa {
    width: 100%;
    border-radius: 12px;
    border: 1px solid var(--color-borde);
    overflow: hidden;
    background: #101013;
  }
  :global(.leaflet-container) {
    background: #101013;
    font-family: inherit;
  }
  :global(.leaflet-bar a) {
    background: #17181a;
    color: #f5f5f4;
    border-bottom-color: #2e2f33;
  }
  :global(.leaflet-bar a:hover) {
    background: #2e2f33;
    color: #fff;
  }
  :global(.leaflet-control-attribution) {
    background: rgba(11, 11, 12, 0.7);
    color: #9b9b9b;
  }
  :global(.leaflet-control-attribution a) {
    color: #9b9b9b;
  }
</style>
