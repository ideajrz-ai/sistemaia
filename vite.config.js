import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig, loadEnv } from 'vite';

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  return {
  envPrefix: ['VITE_', 'PUBLIC_'],
  plugins: [sveltekit()],
  assetsInclude: ['**/*.png', '**/*.svg'],
  server: {
    proxy: {
      '/api': { target: env.API_DEV_URL || 'http://127.0.0.1:3001', changeOrigin: true },
    },
  },
  };
});
