import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider, useAuth } from './contexts/AuthContext'
import Login from './pages/Login'
import AdminLayout from './components/AdminLayout'
import AdminDashboard from './pages/AdminDashboard'
import JobRolesManagement from './pages/JobRolesManagement'
import SkillsManagement from './pages/SkillsManagement'
import AnalyticsDashboard from './pages/AnalyticsDashboard'
import MarketDataMaintenance from './pages/MarketDataMaintenance'
import UserManagement from './pages/UserManagement'

function AppRoutes() {
  const { isAdmin } = useAuth()

  return (
    <Routes>
      <Route path="/login" element={isAdmin ? <Navigate to="/" replace /> : <Login />} />
      <Route
        path="/"
        element={isAdmin ? <AdminLayout /> : <Navigate to="/login" replace />}
      >
        <Route index element={<AdminDashboard />} />
        <Route path="jobs" element={<JobRolesManagement />} />
        <Route path="skills" element={<SkillsManagement />} />
        <Route path="analytics" element={<AnalyticsDashboard />} />
        <Route path="market" element={<MarketDataMaintenance />} />
        <Route path="users" element={<UserManagement />} />
      </Route>
      <Route path="*" element={<Navigate to={isAdmin ? '/' : '/login'} replace />} />
    </Routes>
  )
}

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <AppRoutes />
      </BrowserRouter>
    </AuthProvider>
  )
}

export default App
