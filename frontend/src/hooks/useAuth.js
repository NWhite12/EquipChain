import { useState, useContext, createContext } from 'react'

const API_URL = import.meta.env.VITE_API_URL
const AuthContext = createContext(null)

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  const register = async (email, password, organizationId) => {
    setLoading(true)
    setError(null)
    try {
      const response = await fetch(`${API_URL}/api/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, organization_id: organizationId }),
      })
      if (!response.ok) throw new Error('Registration failed')

      const data = await response.json()
      localStorage.setItem('token', data.token)
      setUser({ email: data.email })
      return data
    } catch (err) {
      setError(err.message)
      throw err
    } finally {
      setLoading(false)
    }
  }

  const login = async (email, password, organizationId) => {
    setLoading(true)
    setError(null)
    try {
      const response = await fetch(`${API_URL}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, organization_id: organizationId }),
      })
      if (!response.ok) throw new Error('Login failed')

      const data = await response.json()
      localStorage.setItem('token', data.token)
      setUser({ email: data.email })
      return data
    } catch (err) {
      setError(err.message)
      throw err
    } finally {
      setLoading(false)
    }
  }


  const logout = () => {
    localStorage.removeItem('token')
    setUser(null)
  }

  const value = { user, loading, error, register, login, logout }
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export const useAuth = () => {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider')
  }
  return context
}
