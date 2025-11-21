import { z } from 'zod'

export const equipmentFormSchema = z.object({
  serialNumber: z
    .string()
    .min(1, 'Serial number is required')
    .min(3, 'Serial number must be at least 3 characters'),

  make: z
    .string()
    .min(1, 'Make is required')
    .min(2, 'Make must be at least 2 characters'),

  model: z
    .string()
    .min(1, 'Model is required')
    .min(2, 'Model must be at least 2 characters'),

  location: z
    .string()
    .trim()
    .min(1, 'Location cannot be empty if provided')
    .optional(),

  statusId: z
    .number()
    .optional(),

  notes: z
    .string()
    .optional(),

  purchasedDate: z
    .string()
    .optional()
    .refine(val => !val || !isNaN(Date.parse(val)), {
      message: 'Invalid date format'
    }),

  warrantyExpires: z
    .string()
    .optional()
    .refine(val => !val || !isNaN(Date.parse(val)), {
      message: 'Invalid date format'
    }),
}).refine(
  (data) => {
    // Warranty must be after purchase date
    if (data.purchasedDate && data.warrantyExpires) {
      return new Date(data.warrantyExpires) > new Date(data.purchasedDate)
    }
    return true
  },
  {
    message: 'Warranty expiration must be after purchase date',
    path: ['warrantyExpires'] // Error appears on warrantyExpires field
  }
)

export const loginSchema = z.object({
  email: z
    .string()
    .email({ message: 'Invalid email address' }),
  password: z
    .string()
    .min(6, 'Password must be at least 6 characters'),
})

export const registerSchema = z.object({
  email: z
    .string()
    .min(1, 'Email is required')
    .email({ message: 'Invalid email address' }),
  password: z
    .string()
    .min(8, 'Password must be at least 8 characters')
    .regex(/[A-Z]/, { message: 'Must contain uppercase letter (A-Z)' })
    .regex(/[a-z]/, { message: 'Must contain lowercase letter (a-z)' })
    .regex(/[0-9]/, { message: 'Must contain number (0-9)' })
    .regex(/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/, {
      message: 'Must contain special character (!@#$%^&* etc)'
    }),
  confirmPassword: z
    .string(),
}).refine((data) => data.password === data.confirmPassword, {
  message: "Passwords don't match",
  path: ['confirmPassword'],
})
