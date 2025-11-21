import { cva } from "class-variance-authority"
import Spinner from "./Spinner"

const buttonStyle = cva(
  "inline-flex items-center justify-center font-semibold transition-colors rounded-md focus:outline-none focus:ring-2 focus:ring-offset-2",
  {
    variants: {
      variant: {
        primary: "bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500",
        secondary: "bg-gray-200 text-gray-900 hover:bg-gray-300 focus:ring-gray-400",
        danger: "bg-red-600 text-white hover:bg-red-700 focus:ring-red-500",
        outline: "border-2 border-gray-300 text-gray-900 hover:bg-gray-50 focus:ring-gray-400",
      },
      size: {
        sm: "text-sm px-3 py-1.5",
        md: "text-base px-4 py-2",
        lg: "text-lg px-6 py-3",
      },
      fullWidth: {
        true: "w-full",
      },
    },
    defaultVariants: {
      variant: "primary",
      size: "md"
    }
  }
)

const spinnerColorMap = {
  primary: "white",
  secondary: "gray",
  danger: "white",
  outline: "blue",
}

export default function Button({
  children,
  variant,
  size,
  fullWidth,
  disabled,
  loading,
  icon: Icon,
  className,
  spinnerColor,
  ...props
}) {
  const defaultSpinnerColor = spinnerColorMap[variant] || "white"
  return (<button
    className={buttonStyle({ variant, size, fullWidth, className })} disabled={disabled || loading} {...props}>
    {loading && <Spinner size="sm" className="mr-2" color={spinnerColor || defaultSpinnerColor} />}
    {Icon && <Icon className="w-4 h-4 mr-2" />}
    {children}</button>)
}

