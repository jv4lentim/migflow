import { useState, useRef, useCallback } from 'react'
import { useQuery } from '@tanstack/react-query'
import { client } from '../api/client'
import { useSchemaStore } from '../store/useSchemaStore'
import type { MigrationDetail, Warning } from '../types/migration'
import { RiskCard } from './RiskBadge'

const SEVERITY_COLORS = {
  error:   { bg: '#2D1B1B', border: '#F85149', badge: 'bg-[#F85149]', text: 'text-[#F85149]' },
  warning: { bg: '#2D2414', border: '#D29922', badge: 'bg-[#D29922]', text: 'text-[#D29922]' },
  info:    { bg: '#1A2435', border: '#58A6FF', badge: 'bg-[#58A6FF]', text: 'text-[#58A6FF]' },
} as const

type Tab = 'code' | 'warnings'

interface WarningItemProps {
  warning: Warning
}

function WarningItem({ warning }: WarningItemProps) {
  const colors = SEVERITY_COLORS[warning.severity]

  return (
    <div
      className="rounded p-3 mb-2 border text-xs"
      style={{ backgroundColor: colors.bg, borderColor: colors.border }}
    >
      <div className="flex items-center gap-2 mb-1 min-w-0">
        <span className={`${colors.badge} text-white text-[10px] font-bold px-1.5 py-0.5 rounded shrink-0`}>
          {warning.severity.toUpperCase()}
        </span>
        <span className="font-mono text-[#7D8590] truncate min-w-0">{warning.rule}</span>
      </div>
      <p className={`${colors.text} font-medium`}>{warning.message}</p>
      {warning.column && (
        <p className="text-[#7D8590] mt-1 truncate font-mono">
          {warning.table}.{warning.column}
        </p>
      )}
    </div>
  )
}

interface Token {
  pattern: RegExp
  color: string
}

const TOKENS: Token[] = [
  { pattern: /#[^\n]*/,                                                              color: '#6A737D' },
  { pattern: /"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'/,                                color: '#9ECBFF' },
  { pattern: /\b(?:def|class|module|end|do|if|elsif|else|unless|true|false|nil|return|self|require|include)\b/, color: '#F97583' },
  { pattern: /:[a-zA-Z_]\w*/,                                                       color: '#79B8FF' },
]

type TokenSegment = { text: string; color?: string }

function tokenizeLine(line: string): TokenSegment[] {
  const segments: TokenSegment[] = []
  let rest = line

  while (rest.length > 0) {
    let earliest: { index: number; match: string; color: string } | null = null

    for (const token of TOKENS) {
      const m = token.pattern.exec(rest)
      if (m !== null && (earliest === null || m.index < earliest.index)) {
        earliest = { index: m.index, match: m[0], color: token.color }
      }
    }

    if (!earliest) {
      segments.push({ text: rest })
      break
    }

    if (earliest.index > 0) segments.push({ text: rest.slice(0, earliest.index) })
    segments.push({ text: earliest.match, color: earliest.color })
    rest = rest.slice(earliest.index + earliest.match.length)
  }

  return segments
}

function CodeTab({ rawContent }: { rawContent: string | null }) {
  if (!rawContent) {
    return (
      <pre className="text-xs font-mono text-[#E6EDF3] p-3 overflow-auto h-full min-h-0 leading-5 whitespace-pre-wrap opacity-50">
        Raw content not available.
      </pre>
    )
  }

  const lines = rawContent.split('\n')
  return (
    <pre className="text-xs font-mono text-[#E6EDF3] p-3 overflow-auto h-full min-h-0 leading-5 whitespace-pre-wrap">
      {lines.map((line, lineIdx) => (
        <span key={lineIdx}>
          {tokenizeLine(line).map((seg, segIdx) =>
            seg.color
              ? <span key={segIdx} style={{ color: seg.color }}>{seg.text}</span>
              : seg.text
          )}
          {lineIdx < lines.length - 1 ? '\n' : null}
        </span>
      ))}
    </pre>
  )
}

function WarningsTab({ warnings }: { warnings: Warning[] }) {
  const grouped = {
    error:   warnings.filter((w) => w.severity === 'error'),
    warning: warnings.filter((w) => w.severity === 'warning'),
    info:    warnings.filter((w) => w.severity === 'info'),
  }

  if (!warnings.length) {
    return (
      <div className="flex flex-col items-center justify-center h-full min-h-[120px] text-[#7D8590] text-sm px-4">
        <span className="text-2xl mb-2">✓</span>
        No warnings found
      </div>
    )
  }

  return (
    <div className="p-3 space-y-4 overflow-auto h-full min-h-0">
      {(['error', 'warning', 'info'] as const).map((severity) =>
        grouped[severity].length > 0 ? (
          <div key={severity}>
            <p className="text-xs font-mono text-[#7D8590] uppercase tracking-widest mb-2">
              {severity} ({grouped[severity].length})
            </p>
            {grouped[severity].map((w, i) => (
              <WarningItem key={i} warning={w} />
            ))}
          </div>
        ) : null
      )}
    </div>
  )
}

function PanelSkeleton() {
  return (
    <div className="animate-pulse p-3 space-y-3 flex-1">
      {Array.from({ length: 5 }).map((_, i) => (
        <div key={i} className="h-3 bg-[#30363D] rounded w-full" />
      ))}
    </div>
  )
}

interface MigrationPaneProps {
  detail:    MigrationDetail
  roleLabel: string
  activeTab: Tab
  onTabChange: (t: Tab) => void
}

function MigrationPane({ detail, roleLabel, activeTab, onTabChange }: MigrationPaneProps) {
  return (
    <div className="flex flex-col h-full min-h-0">
      <div className="px-3 py-2 border-b border-[#30363D] shrink-0">
        <p className="text-[10px] font-mono text-[#58A6FF] uppercase tracking-wider">{roleLabel}</p>
        <p className="text-sm font-semibold truncate">{detail.name}</p>
        <p className="text-xs font-mono text-[#7D8590] truncate">{detail.version}</p>
      </div>

      <RiskCard
        score={detail.risk_score}
        level={detail.risk_level}
        factors={detail.risk_factors}
      />

      <div className="flex border-b border-[#30363D] shrink-0">
        {(['code', 'warnings'] as Tab[]).map((tab) => (
          <button
            key={tab}
            type="button"
            onClick={() => onTabChange(tab)}
            className={`flex-1 py-1.5 text-xs font-mono uppercase tracking-wider transition-colors ${
              activeTab === tab
                ? 'text-[#58A6FF] border-b-2 border-[#58A6FF]'
                : 'text-[#7D8590] hover:text-[#E6EDF3]'
            }`}
          >
            {tab}
            {tab === 'warnings' && detail.warnings.length > 0 && (
              <span className="ml-1 bg-[#F85149] text-white text-[10px] px-1 rounded-full">
                {detail.warnings.length}
              </span>
            )}
          </button>
        ))}
      </div>

      <div className="flex-1 min-h-0 flex flex-col overflow-hidden">
        {activeTab === 'code'
          ? <CodeTab rawContent={detail.raw_content} />
          : <WarningsTab warnings={detail.warnings} />}
      </div>
    </div>
  )
}

const MIN_SPLIT = 20
const MAX_SPLIT = 80

export function DetailPanel() {
  const [baseTab, setBaseTab] = useState<Tab>('code')
  const [targetTab, setTargetTab] = useState<Tab>('code')
  const [splitPct, setSplitPct] = useState(50)
  const containerRef = useRef<HTMLDivElement>(null)
  const dragging = useRef(false)

  const onDividerMouseDown = useCallback((e: React.MouseEvent) => {
    dragging.current = true
    e.preventDefault()

    const onMouseMove = (ev: MouseEvent) => {
      if (!dragging.current || !containerRef.current) return
      const rect = containerRef.current.getBoundingClientRect()
      const pct = ((ev.clientY - rect.top) / rect.height) * 100
      setSplitPct(Math.min(MAX_SPLIT, Math.max(MIN_SPLIT, pct)))
    }

    const onMouseUp = () => {
      dragging.current = false
      document.removeEventListener('mousemove', onMouseMove)
      document.removeEventListener('mouseup', onMouseUp)
    }

    document.addEventListener('mousemove', onMouseMove)
    document.addEventListener('mouseup', onMouseUp)
  }, [])
  const { selectedVersion, compareTo } = useSchemaStore()

  const compareSplit =
    !!selectedVersion
    && !!compareTo
    && compareTo !== selectedVersion

  const { data: baseDetail, isPending: loadingBase } = useQuery({
    queryKey: ['migration', selectedVersion],
    queryFn:  () => client.getMigrationDetail(selectedVersion!),
    enabled:  !!selectedVersion,
  })

  const { data: targetDetail, isPending: loadingTarget } = useQuery({
    queryKey: ['migration', compareTo],
    queryFn:  () => client.getMigrationDetail(compareTo!),
    enabled:  compareSplit,
  })

  if (!selectedVersion) return null

  if (loadingBase || !baseDetail) {
    return (
      <div className="flex flex-col h-full">
        <PanelSkeleton />
      </div>
    )
  }

  if (!compareSplit) {
    return (
      <div className="flex flex-col h-full min-h-0">
        <MigrationPane
          detail={baseDetail}
          roleLabel="Migration"
          activeTab={baseTab}
          onTabChange={setBaseTab}
        />
      </div>
    )
  }

  return (
    <div ref={containerRef} className="flex flex-col h-full min-h-0">
      <div className="flex flex-col min-h-0 overflow-hidden" style={{ height: `${splitPct}%` }}>
        <MigrationPane
          detail={baseDetail}
          roleLabel="Base"
          activeTab={baseTab}
          onTabChange={setBaseTab}
        />
      </div>

      <div
        role="separator"
        aria-orientation="horizontal"
        onMouseDown={onDividerMouseDown}
        className="h-1 shrink-0 cursor-row-resize bg-[#30363D] hover:bg-[#58A6FF] transition-colors duration-150 select-none"
      />

      <div className="flex flex-col min-h-0 overflow-hidden flex-1">
        {loadingTarget || !targetDetail
          ? (
              <div className="flex flex-col h-full min-h-0">
                <div className="px-3 py-2 border-b border-[#30363D] shrink-0">
                  <p className="text-[10px] font-mono text-[#58A6FF] uppercase tracking-wider">Target</p>
                  <p className="text-xs text-[#7D8590] font-mono">Loading…</p>
                </div>
                <PanelSkeleton />
              </div>
            )
          : (
              <MigrationPane
                detail={targetDetail}
                roleLabel="Target"
                activeTab={targetTab}
                onTabChange={setTargetTab}
              />
            )}
      </div>
    </div>
  )
}
