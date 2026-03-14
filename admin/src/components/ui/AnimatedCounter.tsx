import { useEffect, useState } from 'react'

interface AnimatedCounterProps {
  value: number
  suffix?: string
  duration?: number
  decimals?: number
}

export function AnimatedCounter({ value, suffix = '', duration = 1.5, decimals = 0 }: AnimatedCounterProps) {
  const [display, setDisplay] = useState(0)
  useEffect(() => {
    let start = 0
    const startTime = performance.now()
    const step = (now: number) => {
      const elapsed = (now - startTime) / 1000
      const t = Math.min(elapsed / duration, 1)
      const eased = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2
      const current = start + (value - start) * eased
      setDisplay(current)
      if (t < 1) requestAnimationFrame(step)
    }
    requestAnimationFrame(step)
  }, [value, duration])
  const formatted = decimals > 0 ? display.toFixed(decimals) : Math.round(display)
  return <span>{formatted}{suffix}</span>
}
