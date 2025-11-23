export default function FormInput({
  label,
  error,
  hint,
  required,
  disabled,
  type = "text",
  ...props
}) {
  return (
    <div className="mb-4">
      {label && (
        <label className="block text-sm font-medium text-gray-900 mb-1">
          {label}
          {required && <span className="text-red-600">*</span>}
        </label>
      )}

      <input type={type}
        disabled={disabled}
        className={`w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 
        transition-colors ${error ? "border-red-500" : "border-gray-300"} ${disabled ? "bg-gray-100" : "bg-white"}`}
        {...props}
      />

      {hint && !error && (
        <p className="mt-1 text-xs text-gray-500">{hint}</p>
      )}

      {error && (<p className="mt-1 text-xs text-red-600">{error}</p>)}
    </div >
  )
}
