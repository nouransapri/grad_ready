import { createContext, useContext, useState, ReactNode } from 'react'

const ADMIN_EMAIL = 'admin@gradready.com'
const ADMIN_PASSWORD = '111111'

type AuthContextType = {
  isAdmin: boolean
  login: (email: string, password: string) => boolean
  logout: () => void
}

const AuthContext = createContext<AuthContextType | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [isAdmin, setIsAdmin] = useState(() => {
    try {
      return sessionStorage.getItem('gradready_admin') === '1'
    } catch {
      return false
    }
  })

  const login = (email: string, password: string) => {
    const ok = email.trim().toLowerCase() === ADMIN_EMAIL && password === ADMIN_PASSWORD
    if (ok) {
      sessionStorage.setItem('gradready_admin', '1')
      setIsAdmin(true)
    }
    return ok
  }

  const logout = () => {
    sessionStorage.removeItem('gradready_admin')
    setIsAdmin(false)
  }

  return (
    <AuthContext.Provider value={{ isAdmin, login, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
