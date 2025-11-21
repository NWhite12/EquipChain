
export default function Skeleton({
  count = 1,
  height = "h-4",
  width = "w-full",
  circle = false,
  className
}) {
  return (
    <>
      {Array.from({ length: count }).map((_, i) => (
        <div
          key={i}
          className={`
            bg-gray-200 animate-pulse rounded
            ${circle ? 'rounded-full' : ''}
            ${height}
            ${width}
            ${className}
            mb-3
          `}
        />
      ))}
    </>
  )
}
