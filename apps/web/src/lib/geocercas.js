// Utilidades del módulo de geocercas.
// NOTA: no importa 'leaflet' estáticamente para no romper el SSR de SvelteKit;
// las funciones que necesitan L lo reciben como parámetro.

const PALETA = ['#e11d48', '#f97316', '#eab308', '#22c55e', '#14b8a6', '#3b82f6', '#8b5cf6', '#ec4899'];

export function nuevoId() {
  return typeof crypto !== 'undefined' && crypto.randomUUID
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

export function colorAleatorio(excluir = []) {
  const opciones = PALETA.filter((c) => !excluir.includes(c));
  return opciones[Math.floor(Math.random() * opciones.length)] || '#3b82f6';
}

// Extrae los datos de una geocerca desde una capa de Leaflet (circle/polygon/rectangle).
// `L` es el objeto leaflet (solo disponible en el navegador).
export function capaAGeocerca(layer, L) {
  if (layer instanceof L.Circle) {
    const c = layer.getLatLng();
    return { tipo: 'circulo', centro: [c.lat, c.lng], radio_m: layer.getRadius() };
  }
  return { tipo: 'poligono', coordenadas: aplanarLatLngs(layer.getLatLngs()) };
}

// Crea la capa de Leaflet que representa una geocerca. `L` solo existe en el navegador.
export function geocercaACapa(g, L) {
  const estilo = { color: g.color || '#3b82f6', weight: 2, fillOpacity: 0.15 };
  if (g.tipo === 'circulo') {
    return L.circle(g.centro, { ...estilo, radius: g.radio_m });
  }
  return L.polygon(g.coordenadas, estilo);
}

// Distancia en metros entre dos puntos [lat, lng] (haversine).
export function distanciaMetros(a, b) {
  const R = 6371000;
  const dLat = ((b[0] - a[0]) * Math.PI) / 180;
  const dLng = ((b[1] - a[1]) * Math.PI) / 180;
  const la1 = (a[0] * Math.PI) / 180;
  const la2 = (b[0] * Math.PI) / 180;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(la1) * Math.cos(la2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

export function puntoEnCirculo(lat, lng, centro, radioM) {
  return distanciaMetros([lat, lng], centro) <= radioM;
}

// Ray casting: ¿el punto [lat,lng] está dentro del polígono de coordenadas [[lat,lng],...]?
export function puntoEnPoligono(lat, lng, coords) {
  let dentro = false;
  for (let i = 0, j = coords.length - 1; i < coords.length; j = i++) {
    const [yi, xi] = coords[i];
    const [yj, xj] = coords[j];
    if (xi > lng !== xj > lng && lat < ((yj - yi) * (lng - xi)) / (xj - xi) + yi) {
      dentro = !dentro;
    }
  }
  return dentro;
}

export function puntoEnGeocerca(g, lat, lng) {
  if (g.tipo === 'circulo') return puntoEnCirculo(lat, lng, g.centro, g.radio_m);
  return puntoEnPoligono(lat, lng, g.coordenadas || []);
}

// Distancia en metros desde un punto [lat,lng] al borde de un polígono [[lat,lng],...].
export function distanciaPuntoPoligono(lat, lng, coords) {
  if (!coords || coords.length < 2) return Infinity;
  const latRef = (lat * Math.PI) / 180;
  const kx = Math.cos(latRef) * 111320;
  const ky = 110540;
  const px = lng * kx;
  const py = lat * ky;
  let min = Infinity;
  for (let i = 0; i < coords.length; i++) {
    const [y1, x1] = coords[i];
    const [y2, x2] = coords[(i + 1) % coords.length];
    const ax = x1 * kx;
    const ay = y1 * ky;
    const bx = x2 * kx;
    const by = y2 * ky;
    const dx = bx - ax;
    const dy = by - ay;
    const len2 = dx * dx + dy * dy;
    const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / len2));
    min = Math.min(min, Math.hypot(px - (ax + t * dx), py - (ay + t * dy)));
  }
  return min;
}

export function geocercasQueContienen(geocercas, lat, lng) {
  return geocercas.filter((g) => puntoEnGeocerca(g, lat, lng));
}

// Área aproximada en m².
export function areaGeocerca(g) {
  if (g.tipo === 'circulo') return Math.PI * g.radio_m * g.radio_m;
  const pts = g.coordenadas || [];
  if (pts.length < 3) return 0;
  const latRef = (pts.reduce((s, p) => s + p[0], 0) / pts.length) * (Math.PI / 180);
  const kx = Math.cos(latRef) * 111320;
  const ky = 110540;
  let area = 0;
  for (let i = 0; i < pts.length; i++) {
    const [y1, x1] = pts[i];
    const [y2, x2] = pts[(i + 1) % pts.length];
    area += x1 * kx * (y2 * ky) - x2 * kx * (y1 * ky);
  }
  return Math.abs(area) / 2;
}

export function formatearArea(m2) {
  if (m2 >= 1_000_000) return `${(m2 / 1_000_000).toFixed(2)} km²`;
  if (m2 >= 10_000) return `${(m2 / 10_000).toFixed(2)} ha`;
  return `${Math.round(m2).toLocaleString('es')} m²`;
}

export function formatearDistancia(m) {
  if (m >= 1000) return `${(m / 1000).toFixed(2)} km`;
  return `${Math.round(m)} m`;
}

// Convierte una geocerca a GeoJSON Feature (los círculos se aproximan con un polígono de 64 lados).
export function aGeoJSON(g) {
  const properties = { nombre: g.nombre, tipo: g.tipo, color: g.color };
  let coordinates;
  if (g.tipo === 'circulo') {
    coordinates = [poligonoAproximadoCirculo(g.centro, g.radio_m, 64)];
    properties.centro = g.centro;
    properties.radio_m = g.radio_m;
  } else {
    coordinates = [(g.coordenadas || []).map(([lat, lng]) => [lng, lat])];
  }
  return {
    type: 'Feature',
    properties,
    geometry: { type: 'Polygon', coordinates },
  };
}

// Convierte un GeoJSON Feature a geocerca interna. Devuelve null si no es compatible.
export function desdeGeoJSON(f) {
  const p = f?.properties || {};
  const base = {
    id: p.id || nuevoId(),
    nombre: p.nombre || 'Geocerca',
    color: p.color || '#3b82f6',
    created_at: p.created_at || new Date().toISOString(),
  };
  if (p.tipo === 'circulo' && Array.isArray(p.centro) && p.radio_m) {
    return { ...base, tipo: 'circulo', centro: p.centro, radio_m: p.radio_m };
  }
  const ring = f?.geometry?.type === 'Polygon' ? f.geometry.coordinates?.[0] : null;
  if (ring && ring.length >= 3) {
    return { ...base, tipo: 'poligono', coordenadas: ring.map(([lng, lat]) => [lat, lng]) };
  }
  return null;
}

// Acepta: { geocercas: [...] }, { features: [...] }, array de Features o de geocercas internas.
export function importarGeocercas(json) {
  const items = Array.isArray(json) ? json : json?.geocercas || json?.features || [];
  return items
    .map((item) => {
      if (!item) return null;
      if (item.geometry) return desdeGeoJSON(item);
      if (item.tipo === 'circulo' && item.centro) {
        return {
          id: item.id || nuevoId(),
          nombre: item.nombre || 'Geocerca',
          tipo: 'circulo',
          color: item.color || '#3b82f6',
          centro: item.centro,
          radio_m: item.radio_m,
          created_at: item.created_at || new Date().toISOString(),
        };
      }
      if (item.tipo === 'poligono' && Array.isArray(item.coordenadas)) {
        return {
          id: item.id || nuevoId(),
          nombre: item.nombre || 'Geocerca',
          tipo: 'poligono',
          color: item.color || '#3b82f6',
          coordenadas: item.coordenadas,
          created_at: item.created_at || new Date().toISOString(),
        };
      }
      return null;
    })
    .filter(Boolean);
}

function aplanarLatLngs(latlngs) {
  const out = [];
  const walk = (x) => {
    if (!x) return;
    if (typeof x.lat === 'number' && typeof x.lng === 'number') {
      out.push([x.lat, x.lng]);
      return;
    }
    if (typeof x.length === 'number') {
      for (let i = 0; i < x.length; i++) walk(x[i]);
    }
  };
  walk(latlngs);
  return out;
}

function poligonoAproximadoCirculo(centro, radioM, lados) {
  const [lat0, lng0] = centro;
  const pts = [];
  for (let i = 0; i < lados; i++) {
    const a = (2 * Math.PI * i) / lados;
    const dLat = (radioM * Math.sin(a)) / 110540;
    const dLng = (radioM * Math.cos(a)) / (111320 * Math.cos((lat0 * Math.PI) / 180));
    pts.push([lng0 + dLng, lat0 + dLat]);
  }
  return pts;
}
