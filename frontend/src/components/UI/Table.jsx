export function Table({ children, className }) {
  return (
    <div className="overflow-x-auto">
      <table className={`w-full border-collapse ${className}`}>
        {children}
      </table>
    </div>
  )
}

export function TableHead({ children, className }) {
  return (
    <thead className={`bg-gray-50 border-b border-gray-200 ${className}`}>
      {children}
    </thead>
  )
}

export function TableBody({ children, className }) {
  return (
    <tbody className={className}>
      {children}
    </tbody>
  )
}

export function TableRow({ children, className, hover = true }) {
  return (
    <tr className={`border-b border-gray-200 ${hover ? "hover:bg-gray-50" : ""} ${className}`}>
      {children}
    </tr>
  )
}

export function TableHeader({ children, className, sortable, onClick }) {
  return (
    <th onClick={onClick}
      className={`px-6 py-3 text-left text-sm font-semibold text-gray-900 ${sortable ? "cursor-pointer hover:bg-gray-100" : ""} ${className}`}>
      {children}
    </th>
  )
}

export function TableCell({ children, className }) {
  return (
    <td className={`px-6 py-4 text-sm text-gray-700 ${className}`}>
      {children}
    </td>
  )
}


Table.Head = TableHead
Table.Body = TableBody
Table.Row = TableRow
Table.Header = TableHeader
Table.Cell = TableCell

