import { useRef, useCallback, useState } from 'react'

interface ResizablePanelProps {
  initialWidth: number
  minWidth: number
  maxWidth: number
  side: 'left' | 'right'
  children: React.ReactNode
  className?: string
}

export function ResizablePanel({
  initialWidth,
  minWidth,
  maxWidth,
  side,
  children,
  className = '',
}: ResizablePanelProps) {
  const [width, setWidth] = useState(initialWidth)
  const dragging   = useRef(false)
  const startX     = useRef(0)
  const startWidth = useRef(0)

  const onMouseDown = useCallback(
    (e: React.MouseEvent) => {
      dragging.current   = true
      startX.current     = e.clientX
      startWidth.current = width

      const onMouseMove = (ev: MouseEvent) => {
        if (!dragging.current) return
        const delta  = side === 'left' ? ev.clientX - startX.current : startX.current - ev.clientX
        const clamped = Math.min(maxWidth, Math.max(minWidth, startWidth.current + delta))
        setWidth(clamped)
      }

      const onMouseUp = () => {
        dragging.current = false
        document.removeEventListener('mousemove', onMouseMove)
        document.removeEventListener('mouseup', onMouseUp)
      }

      document.addEventListener('mousemove', onMouseMove)
      document.addEventListener('mouseup', onMouseUp)
      e.preventDefault()
    },
    [width, minWidth, maxWidth, side],
  )

  const handleSide = side === 'left' ? 'right-0' : 'left-0'

  return (
    <div className={`relative shrink-0 ${className}`} style={{ width }}>
      {children}
      <div
        role="separator"
        aria-orientation="vertical"
        onMouseDown={onMouseDown}
        className={`absolute top-0 ${handleSide} w-1 h-full cursor-col-resize bg-[#30363D] hover:bg-[#58A6FF] transition-colors duration-150 z-10 select-none`}
      />
    </div>
  )
}
