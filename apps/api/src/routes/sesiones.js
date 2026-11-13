import { crudRecurso } from './recurso.js';

// Sesiones de consultoria por cliente (admin puede crear para un cliente_id)
export default crudRecurso('sesiones', { adminPuedeElegirCliente: true });
