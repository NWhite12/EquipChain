import { Dialog, DialogPanel, DialogTitle } from "@headlessui/react"
import { XMarkIcon } from "@heroicons/react/24/solid"

export default function Modal({
  isOpen,
  onClose,
  title,
  children,
  footer,
  className
}) {
  return (
    <Dialog open={isOpen} onClose={onClose} className="relative z-50">
      <div className="fixed inset-0 flex items-center justify-center p-4">
        <DialogPanel className={`bg-white rounded-lg shadow-xl max-w-md w-full ${className}`}>
          <div className="flex items-center justify-between p-6 border-b boarder-grey-200">
            {title && <DialogTitle className="text-lg font-bold">{title}</DialogTitle>}
            <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
              <XMarkIcon className="w-6 h-6" />
            </button>
          </div>

          <div className="p-6">
            {children}
          </div>

          <div className="flex gap-3 p-6 border-t border-gray-200 justify-end">
            {footer}
          </div>
        </DialogPanel>
      </div>
    </Dialog>
  )
}
