import '@testing-library/jest-dom/vitest'
import { vi } from 'vitest'

const localStorageMock = (() => {
  let store: Record<string, string> = {}
  return {
    getItem: (key: string) => store[key] || null,
    setItem: (key: string, value: string) => {
      store[key] = value ? value.toString() : ''
    },
    clear: () => {
      store = {}
    },
    removeItem: (key: string) => {
      delete store[key]
    },
    key: vi.fn(),
    length: 0,
  }
})()

Object.defineProperty(window, 'localStorage', {
  value: localStorageMock,
})
