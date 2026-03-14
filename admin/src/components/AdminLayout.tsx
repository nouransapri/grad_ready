import { Outlet, NavLink, useNavigate } from 'react-router-dom'
import { Shield, LayoutGrid, Briefcase, Award, TrendingUp, Database, ArrowRight, Users, BarChart3 } from 'lucide-react'
import { useAuth } from '../contexts/AuthContext'

const tabs = [
  { to: '/', label: 'Overview', icon: LayoutGrid },
  { to: '/jobs', label: 'Jobs', icon: Briefcase },
  { to: '/skills', label: 'Skills', icon: Award },
  { to: '/analytics', label: 'Analytics', icon: TrendingUp },
  { to: '/market', label: 'Market', icon: Database },
  { to: '/users', label: 'Users', icon: Users },
  { to: '/analysis', label: 'Analysis', icon: BarChart3 },
]

export default function AdminLayout() {
  const { logout } = useAuth()
  const navigate = useNavigate()

  const handleLogout = () => {
    logout()
    navigate('/login', { replace: true })
  }

  return (
    <div className="min-h-screen bg-gray-100">
      <header className="bg-gradient-to-r from-purple-600 to-indigo-600 text-white px-4 py-4">
        <div className="max-w-md mx-auto flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Shield className="w-8 h-8" />
            <div>
              <h1 className="text-xl font-bold">Admin Panel</h1>
              <p className="text-white/80 text-sm">GradReady Management</p>
            </div>
          </div>
          <button
            onClick={handleLogout}
            className="p-2 rounded-xl hover:bg-white/20 transition"
            aria-label="Logout"
          >
            <ArrowRight className="w-6 h-6" />
          </button>
        </div>
        <nav className="max-w-md mx-auto mt-4 overflow-x-auto flex gap-2 pb-2">
          {tabs.map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              end={to === '/'}
              className={({ isActive }) =>
                `flex items-center gap-2 px-4 py-2 rounded-xl whitespace-nowrap transition ${
                  isActive ? 'bg-white text-purple-600' : 'text-white hover:bg-white/20'
                }`
              }
            >
              <Icon className="w-5 h-5" />
              {label}
            </NavLink>
          ))}
        </nav>
      </header>
      <main className="max-w-md mx-auto p-4 pb-8 space-y-6">
        <Outlet />
      </main>
    </div>
  )
}
