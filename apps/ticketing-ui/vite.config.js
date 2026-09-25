import { defineConfig } from 'vite'

export default defineConfig({
  server: {
    proxy: {
      '/api/films': 'http://localhost:8081',
      '/api/layouts': 'http://localhost:8082',
      '/api/checkout': 'http://localhost:8083',
      '/api/wallet': 'http://localhost:8084',
      '/api/payments': 'http://localhost:8084',
    }
  }
})
