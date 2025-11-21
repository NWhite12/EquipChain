import { cva } from "class-variance-authority"

const badgeStyles = cva(
  "inline-flex items-center justify-center font-medium rounded",
  {
    variants: {
      variant: {
        default: "bg-gray-100 text-gray-800",
        success: "bg-green-100 text-green-800",
        warning: "bg-yellow-100 text-yellow-800",
        danger: "bg-red-100 text-red-800",
        info: "bg-blue-100 text-blue-800",
      },
      size: {
        sm: "text-xs px-2 py-1",
        md: "text-sm px-3 py-1",
      },
      rounded: {
        true: "rounded-full",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "md",
      rounded: false,
    },
    compoundVariants: [
      {
        rounded: false,
        className: "rounded",
      },
    ],
  }
)

export default function Badge({ children, variant, size, rounded, className }) {
  return (
    <span className={badgeStyles({ variant, size, rounded, className })}>
      {children}
    </span>
  )
}
