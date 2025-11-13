import { Link } from 'react-router-dom'

export default function Navigation() {
  return (
    <nav className="bg-gray-900 text-white w-64 p-6">
      <div className="mb-8">
        <h2 className="text-xl font-bold mb-4">Menu</h2>
        <ul className="space-y-4">
          <li><Link to="/" className="hover:text-blue-400">Home</Link></li>
          <li><Link to="/dashboard" className="hover:text-blue-400">Dashboard</Link></li>
          <li><Link to="/login" className="hover:text-blue-400">Login</Link></li>
        </ul>
      </div>
    </nav>
  )
}
