/// <reference types="vitest" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  // @ts-expect-error vitest types are not automatically merged into vite types
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/tests/setup.ts'],
    exclude: ['e2e/**', 'node_modules/**', 'dist/**'],
  },
})
