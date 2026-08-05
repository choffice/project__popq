function uuidFromRandomBytes(cryptoApi: Crypto) {
  const bytes = cryptoApi.getRandomValues(new Uint8Array(16))
  bytes[6] = (bytes[6] & 0x0f) | 0x40
  bytes[8] = (bytes[8] & 0x3f) | 0x80

  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0'))
  return [
    hex.slice(0, 4).join(''),
    hex.slice(4, 6).join(''),
    hex.slice(6, 8).join(''),
    hex.slice(8, 10).join(''),
    hex.slice(10, 16).join(''),
  ].join('-')
}

/**
 * Creates a browser-local identifier without requiring a secure context.
 *
 * `crypto.randomUUID()` is unavailable when a phone opens the QR menu through
 * a plain HTTP LAN address. `getRandomValues()` works in that context on the
 * browsers we support, with a timestamp/random fallback for older WebViews.
 */
export function createClientId() {
  const cryptoApi = globalThis.crypto

  if (typeof cryptoApi?.randomUUID === 'function') {
    try {
      return cryptoApi.randomUUID()
    } catch {
      // Continue with the non-secure-context-compatible path.
    }
  }

  if (typeof cryptoApi?.getRandomValues === 'function') {
    try {
      return uuidFromRandomBytes(cryptoApi)
    } catch {
      // Some embedded WebViews expose Crypto but reject its methods.
    }
  }

  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}-${Math.random().toString(36).slice(2)}`
}
