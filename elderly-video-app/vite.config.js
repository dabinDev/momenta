import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    host: '0.0.0.0',
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:10099',
        changeOrigin: true,
      },
      '/media': {
        target: 'http://127.0.0.1:10099',
        changeOrigin: true,
      },
    },
  },
  resolve: {
    alias: {
      '@': '/src',
    },
  },
  build: {
    target: 'es2018',
    outDir: 'dist',
    chunkSizeWarningLimit: 1024,
  },
})
