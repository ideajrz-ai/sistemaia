import { crudRecurso } from './recurso.js';

// Citas con recordatorios (admin puede agendar para un cliente_id)
export default crudRecurso('citas', { adminPuedeElegirCliente: true });
