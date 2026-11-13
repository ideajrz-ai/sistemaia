<script>
  import { onMount } from 'svelte';
  import { requireSession } from '$lib/auth.js';
  import { supabase } from '$lib/supabase.js';

  let cargando = true;
  let esAdmin = false;
  let error = '';
  let exito = '';

  let anuncios = [];
  let form = { titulo: '', mensaje: '', tipo: 'info', activo: true };
  let guardando = false;
  let editando = null;

  onMount(async () => {
    const session = await requireSession();
    if (!session) return;

    const { data: perfil } = await supabase
      .from('perfiles')
      .select('rol')
      .eq('id', session.user.id)
      .single();

    if (!perfil || perfil.rol !== 'admin') {
      cargando = false;
      error = 'Acceso denegado: se requiere rol de administrador.';
      return;
    }
    esAdmin = true;
    await cargar();
  });

  async function cargar() {
    const { data, error: err } = await supabase
      .from('anuncios')
      .select('*')
      .order('created_at', { ascending: false });
    if (err) error = err.message;
    else anuncios = data || [];
    cargando = false;
  }

  function editar(a) {
    editando = a.id;
    form = { titulo: a.titulo, mensaje: a.mensaje, tipo: a.tipo, activo: a.activo };
    error = '';
    exito = '';
  }

  function cancelar() {
    editando = null;
    form = { titulo: '', mensaje: '', tipo: 'info', activo: true };
  }

  async function guardar() {
    error = '';
    exito = '';
    guardando = true;
    try {
      const { data: { user } } = await supabase.auth.getUser();
      const payload = { ...form };
      const { error: err } = editando
        ? await supabase.from('anuncios').update(payload).eq('id', editando)
        : await supabase.from('anuncios').insert({ ...payload, autor_id: user.id });
      if (err) throw new Error(err.message);
      exito = editando ? 'Anuncio actualizado.' : 'Anuncio publicado.';
      cancelar();
      await cargar();
    } catch (e) {
      error = e.message;
    } finally {
      guardando = false;
    }
  }

  async function alternarActivo(a) {
    error = '';
    const { error: err } = await supabase
      .from('anuncios')
      .update({ activo: !a.activo })
      .eq('id', a.id);
    if (err) error = err.message;
    else await cargar();
  }

  async function eliminar(a) {
    if (!confirm(`¿Eliminar el anuncio "${a.titulo}"?`)) return;
    error = '';
    const { error: err } = await supabase.from('anuncios').delete().eq('id', a.id);
    if (err) error = err.message;
    else await cargar();
  }
</script>

<svelte:head><title>Anuncios · Admin · SistemaIA</title></svelte:head>

{#if cargando}
  <div class="tarjeta"><p class="tenue">Cargando…</p></div>
{:else if !esAdmin}
  <div class="tarjeta"><p class="error">{error}</p></div>
{:else}
  <div class="tarjeta">
    <h1>Anuncios para clientes</h1>
    <p class="tenue">Los anuncios activos aparecen en la pantalla de bienvenida de tus clientes.</p>

    <h2>{editando ? 'Editar anuncio' : 'Nuevo anuncio'}</h2>
    <div class="campo">
      <label for="a-titulo">Título</label>
      <input id="a-titulo" type="text" bind:value={form.titulo} placeholder="Ej. Cierre de oficina por mantenimiento" />
    </div>
    <div class="campo">
      <label for="a-mensaje">Mensaje</label>
      <textarea id="a-mensaje" rows="4" bind:value={form.mensaje} placeholder="Escribe el anuncio…"></textarea>
    </div>
    <div class="campo" style="display:flex; gap:1rem; align-items:center; flex-wrap:wrap;">
      <div>
        <label for="a-tipo">Tipo</label>
        <select id="a-tipo" bind:value={form.tipo}>
          <option value="info">Información</option>
          <option value="aviso">Aviso</option>
          <option value="importante">Importante</option>
        </select>
      </div>
      <label style="display:flex; align-items:center; gap:.4rem; margin:0;">
        <input type="checkbox" bind:checked={form.activo} /> Activo
      </label>
    </div>
    {#if error}<p class="error">{error}</p>{/if}
    {#if exito}<p class="exito">{exito}</p>{/if}
    <div style="display:flex; gap:.75rem;">
      <button class="boton" on:click={guardar} disabled={guardando || !form.titulo || !form.mensaje}>
        {guardando ? 'Guardando…' : editando ? 'Guardar cambios' : 'Publicar anuncio'}
      </button>
      {#if editando}
        <button class="boton boton-secundario" on:click={cancelar}>Cancelar</button>
      {/if}
    </div>
  </div>

  <div class="tarjeta">
    <h2>Anuncios publicados ({anuncios.length})</h2>
    {#if anuncios.length === 0}
      <p class="tenue">Aún no hay anuncios.</p>
    {:else}
      <table class="tabla">
        <thead>
          <tr><th>Título</th><th>Tipo</th><th>Estado</th><th>Fecha</th><th></th></tr>
        </thead>
        <tbody>
          {#each anuncios as a}
            <tr>
              <td>{a.titulo}</td>
              <td>{a.tipo}</td>
              <td>{a.activo ? 'Activo' : 'Oculto'}</td>
              <td>{new Date(a.created_at).toLocaleDateString('es')}</td>
              <td style="white-space:nowrap;">
                <button class="boton boton-secundario" style="padding:.3rem .7rem; font-size:.8rem;" on:click={() => editar(a)}>Editar</button>
                <button class="boton boton-secundario" style="padding:.3rem .7rem; font-size:.8rem;" on:click={() => alternarActivo(a)}>
                  {a.activo ? 'Ocultar' : 'Mostrar'}
                </button>
                <button class="boton boton-secundario" style="padding:.3rem .7rem; font-size:.8rem;" on:click={() => eliminar(a)}>Eliminar</button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
{/if}
