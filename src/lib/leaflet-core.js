import L from 'leaflet';

// Configurar los iconos por defecto de Leaflet con URLs absolutas
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: '/images/marker-icon-2x.png',
  iconUrl: '/images/marker-icon.png',
  shadowUrl: '/images/marker-shadow.png',
});

// leaflet-draw es UMD y espera L como global; lo exponemos antes de importarlo.
window.L = L;

export default L;
