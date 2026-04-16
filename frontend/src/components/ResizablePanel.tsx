import { useRef, useCallback, useState } from 'react'

const RAIL_WIDTH = 44

interface ResizablePanelProps {
  initialWidth: number
  minWidth: number
  maxWidth: number
  side: 'left' | 'right'
  children: React.ReactNode
  className?: string
  /** When set, panel snaps to a narrow rail; children should stay mounted (e.g. hidden via wrapper). */
  collapsed?: boolean
  onToggleCollapse?: () => void
}

export function ResizablePanel({
  initialWidth,
  minWidth,
  maxWidth,
  side,
  children,
  className = '',
  collapsed = false,
  onToggleCollapse,
}: ResizablePanelProps) {
  const [width, setWidth] = useState(initialWidth)
  const dragging = useRef(false)
  const startX = useRef(0)
  const startWidth = useRef(0)

  /** Expanded width stays in state; when collapsed we only render at rail width. */
  const displayWidth = collapsed ? RAIL_WIDTH : width

  const onMouseDown = useCallback(
    (e: React.MouseEvent) => {
      if (collapsed) return
      dragging.current = true
      startX.current = e.clientX
      startWidth.current = width

      const onMouseMove = (ev: MouseEvent) => {
        if (!dragging.current) return
        const delta = side === 'left' ? ev.clientX - startX.current : startX.current - ev.clientX
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
    [width, minWidth, maxWidth, side, collapsed],
  )

  const handleSide = side === 'left' ? 'right-0' : 'left-0'

  return (
    <div
      className={`relative shrink-0 flex min-h-0 ${className}`}
      style={{ width: displayWidth }}
    >
      {collapsed && onToggleCollapse && (
        <div
          className={`flex flex-col items-center pt-3 shrink-0 ${side === 'right' ? 'border-l border-[#30363D]' : 'border-r border-[#30363D]'} bg-[#0D1117] w-full min-h-0`}
        >
          <button
            type="button"
            onClick={onToggleCollapse}
            aria-label="Expand panel"
            className="p-1.5 rounded-md text-[#7D8590] hover:text-[#58A6FF] hover:bg-[#21262D] transition-colors"
          >
            {side === 'right'
              ? (
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
                    <path d="M15 18l-6-6 6-6" />
                  </svg>
                )
              : (
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
                    <path d="M9 18l6-6-6-6" />
                  </svg>
                )}
          </button>
        </div>
      )}

      <div
        className={`flex-1 min-w-0 min-h-0 flex flex-col overflow-hidden ${collapsed ? 'hidden' : ''}`}
      >
        {children}
      </div>

      {!collapsed && (
        <div
          role="separator"
          aria-orientation="vertical"
          onMouseDown={onMouseDown}
          className={`absolute top-0 ${handleSide} w-1 h-full cursor-col-resize bg-[#30363D] hover:bg-[#58A6FF] transition-colors duration-150 z-10 select-none`}
        />
      )}
    </div>
  )
}
