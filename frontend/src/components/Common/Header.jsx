export default function Header() {
  return (
    <header className="bg-white border-b border-gray-200 px-6 py-4">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-blue-600">EquipChain</h1>
        <div className="flex items-center gap-4">
          <span className="text-gray-600">Welcome, User</span>
          <button className="bg-red-600 text-white px-4 py-2 rounded">
            Logout
          </button>
        </div>
      </div>
    </header>
  )
}
