export default function EmptyState({
  icon: Icon,
  title,
  message,
  action,
  onAction
}) {
  return (
    <div className="flex flex-col items-center justify-center py-12 px-4">
      {Icon && (
        <Icon className="w-16 h-16 text-gray-300 mb-4" />
      )}
      <h3 className="text-lg font-semibold text-gray-900 mb-2">{title}</h3>
      <p className="text-gray-600 text-center mb-6 max-w-md">{message}</p>
      {action && onAction && (
        <button
          onClick={onAction}
          className="px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
        >
          {action}
        </button>
      )}
    </div>
  )
}
