import { useEffect, useState } from 'react'

export type ThemePreference = 'light' | 'dark'

export const CUSTOMER_THEME_KEY = 'popq.customer.web.theme.preference.v1'

function readTheme(storageKey: string): ThemePreference {
  try {
    return window.localStorage.getItem(storageKey) === 'dark' ? 'dark' : 'light'
  } catch {
    return 'light'
  }
}

export function useThemePreference(storageKey = CUSTOMER_THEME_KEY) {
  const [theme, setTheme] = useState<ThemePreference>(() => readTheme(storageKey))

  useEffect(() => {
    document.documentElement.dataset.theme = theme
    document.documentElement.style.colorScheme = theme

    try {
      window.localStorage.setItem(storageKey, theme)
    } catch {
      // Theme changes still work when storage is unavailable.
    }

    return () => {
      delete document.documentElement.dataset.theme
      document.documentElement.style.removeProperty('color-scheme')
    }
  }, [storageKey, theme])

  return {
    theme,
    toggleTheme: () => setTheme((current) => (current === 'dark' ? 'light' : 'dark')),
  }
}
