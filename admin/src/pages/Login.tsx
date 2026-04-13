import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Shield } from 'lucide-react'
import { useAuth } from '../contexts/AuthContext'
import { toast } from 'sonner'

export default function Login() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const { login } = useAuth()
  const navigate = useNavigate()

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (login(email, password)) {
      toast.success('Welcome to GradReady Admin')
      navigate('/', { replace: true })
    } else {
      toast.error('Invalid email or password. Use admin@gradready.com / 111111')
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-purple-600 to-indigo-600 flex flex-col items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="flex items-center gap-3 text-white mb-8">
          <Shield className="w-10 h-10" />
          <div>
            <h1 className="text-2xl font-bold">Admin Panel</h1>
            <p className="text-white/80 text-sm">GradReady Management</p>
          </div>
        </div>
        <form
          onSubmit={handleSubmit}
          className="bg-white/10 backdrop-blur border border-white/20 rounded-2xl p-6 shadow-xl"
        >
          <h2 className="text-xl font-bold text-white text-center mb-6">Login</h2>
          <input
            type="text"
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full px-4 py-3 rounded-xl border border-gray-300 focus:ring-2 focus:ring-purple-500 focus:border-transparent mb-4"
            autoComplete="username"
          />
          <input
            type="password"
            placeholder="Password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full px-4 py-3 rounded-xl border border-gray-300 focus:ring-2 focus:ring-purple-500 focus:border-transparent mb-6"
            autoComplete="current-password"
          />
          <button
            type="submit"
            className="w-full py-3 rounded-xl bg-white text-purple-600 font-bold hover:bg-gray-100 transition"
          >
            Login
          </button>
        </form>
        <p className="text-white/70 text-center text-sm mt-4">
          Admin: admin@gradready.com / 111111
        </p>
      </div>
    </div>
  )
}
