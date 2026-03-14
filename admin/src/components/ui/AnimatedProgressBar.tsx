import { motion } from 'motion/react'

interface AnimatedProgressBarProps {
  value: number
  color?: 'blue' | 'purple' | 'green' | 'orange'
  className?: string
}

const colorClasses = {
  blue: 'bg-blue-500',
  purple: 'bg-purple-500',
  green: 'bg-green-500',
  orange: 'bg-orange-500',
}

const gradientStyles = {
  blue: 'linear-gradient(to right, #3b82f6, #2563eb)',
  purple: 'linear-gradient(to right, #a855f7, #9333ea)',
  green: 'linear-gradient(to right, #22c55e, #16a34a)',
  orange: 'linear-gradient(to right, #f59e0b, #d97706)',
}

export function AnimatedProgressBar({ value, color = 'blue', className = '' }: AnimatedProgressBarProps) {
  const pct = Math.min(100, Math.max(0, value))
  const useGradient = color === 'blue' || color === 'purple'
  return (
    <div className={`h-2.5 rounded-full bg-gray-200 overflow-hidden ${className}`}>
      <motion.div
        className={!useGradient ? `h-full rounded-full ${colorClasses[color]}` : 'h-full rounded-full'}
        style={useGradient ? { background: gradientStyles[color] } : undefined}
        initial={{ width: 0 }}
        animate={{ width: `${pct}%` }}
        transition={{ duration: 0.8, ease: 'easeOut' }}
      />
    </div>
  )
}
