import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  base: '/myown/',
  server: {
    port: 5173,
    proxy: {
      '/myown/api': {
        target: 'http://localhost:52773',
        changeOrigin: true,
      },
    },
  },
})
