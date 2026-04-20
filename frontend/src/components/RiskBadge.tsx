import { useState } from 'react'
import type { RiskFactor, RiskLevel } from '../types/migration'

const COLORS: Record<RiskLevel, string> = {
  safe:   'bg-[#1A3A1A] text-[#3FB950] border border-[#3FB950]/30',
  low:    'bg-[#2D2414] text-[#D29922] border border-[#D29922]/30',
  medium: 'bg-[#2D1F0A] text-[#E8862A] border border-[#E8862A]/30',
  high:   'bg-[#2D1B1B] text-[#F85149] border border-[#F85149]/30',
}

interface RiskBadgeProps {
  score: number
  level: RiskLevel
  compact?: boolean
}

export function RiskBadge({ score, level, compact = false }: RiskBadgeProps) {
  if (level === 'safe' && score === 0) {
    return (
      <span className={`inline-flex items-center gap-1 text-[10px] font-mono font-semibold px-1.5 py-0.5 rounded ${COLORS.safe}`}>
        {!compact && <span className="opacity-70">RISK</span>}
        <span>SAFE</span>
      </span>
    )
  }

  return (
    <span className={`inline-flex items-center gap-1 text-[10px] font-mono font-semibold px-1.5 py-0.5 rounded ${COLORS[level]}`}>
      {!compact && <span className="opacity-70">RISK</span>}
      <span>{score}</span>
      <span>{level.toUpperCase()}</span>
    </span>
  )
}

interface RiskCardProps {
  score: number
  level: RiskLevel
  factors: RiskFactor[]
}

const BAR_COLORS: Record<RiskLevel, string> = {
  safe:   'bg-[#3FB950]',
  low:    'bg-[#D29922]',
  medium: 'bg-[#E8862A]',
  high:   'bg-[#F85149]',
}

export function RiskCard({ score, level, factors }: RiskCardProps) {
  const [expanded, setExpanded] = useState(false)

  return (
    <div className="mx-3 mt-3 mb-1 rounded border border-[#30363D] bg-[#161B22] overflow-hidden">
      <button
        type="button"
        onClick={() => setExpanded((v) => !v)}
        className="w-full flex items-center gap-2 px-3 pt-3 pb-2 text-left"
      >
        <span className="text-[10px] font-mono text-[#7D8590] uppercase tracking-widest flex-1">
          Risk Score
        </span>
        <RiskBadge score={score} level={level} />
        {factors.length > 0 && (
          <svg
            className={`w-3 h-3 text-[#7D8590] shrink-0 transition-transform duration-150 ${expanded ? 'rotate-180' : ''}`}
            viewBox="0 0 12 12"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.5"
          >
            <path d="M2 4l4 4 4-4" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        )}
      </button>

      <div className="px-3 pb-3">
        <div className="w-full h-1.5 bg-[#30363D] rounded-full overflow-hidden">
          <div
            className={`h-full rounded-full transition-all ${BAR_COLORS[level]}`}
            style={{ width: `${score}%` }}
          />
        </div>
      </div>

      {expanded && factors.length > 0 && (
        <div className="border-t border-[#30363D] px-3 py-2 space-y-1 max-h-48 overflow-y-auto">
          {factors.map((f, i) => (
            <div key={i} className="flex items-start justify-between gap-2 text-[10px]">
              <span className="text-[#7D8590] font-mono truncate">{f.rule}</span>
              <span className="text-[#7D8590] shrink-0">+{f.weight}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
