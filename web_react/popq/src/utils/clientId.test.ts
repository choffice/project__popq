import { afterEach, describe, expect, it, vi } from 'vitest'
import { createClientId } from './clientId'

describe('createClientId', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('uses randomUUID when the browser provides it', () => {
    const randomUUID = vi.fn(() => 'native-uuid')
    vi.stubGlobal('crypto', { randomUUID })

    expect(createClientId()).toBe('native-uuid')
    expect(randomUUID).toHaveBeenCalledOnce()
  })

  it('creates an RFC 4122 v4 id when randomUUID is unavailable', () => {
    vi.stubGlobal('crypto', {
      getRandomValues: (bytes: Uint8Array) => {
        bytes.forEach((_, index) => {
          bytes[index] = index
        })
        return bytes
      },
    })

    expect(createClientId()).toBe('00010203-0405-4607-8809-0a0b0c0d0e0f')
  })

  it('still creates a valid API key when Crypto is unavailable', () => {
    vi.stubGlobal('crypto', undefined)

    expect(createClientId()).toMatch(/^[a-z0-9-]{8,100}$/)
  })
})
