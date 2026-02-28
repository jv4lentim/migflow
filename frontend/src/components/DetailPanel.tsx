import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { client } from '../api/client'
import { useSchemaStore } from '../store/useSchemaStore'
import type { Warning } from '../types/migration'

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
      <div className="flex items-center gap-2 mb-1">
        <span className={`${colors.badge} text-white text-[10px] font-bold px-1.5 py-0.5 rounded`}>
          {warning.severity.toUpperCase()}
        </span>
        <span className="font-mono text-[#7D8590]">{warning.rule}</span>
      </div>
      <p className={`${colors.text} font-medium`}>{warning.message}</p>
      {warning.column && (
        <p className="text-[#7D8590] mt-1">
          <span className="font-mono">{warning.table}.{warning.column}</span>
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

function escapeHtml(str: string): string {
  return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}

function highlightLine(line: string): string {
  let result  = ''
  let rest    = line

  while (rest.length > 0) {
    let earliest: { index: number; match: string; color: string } | null = null

    for (const token of TOKENS) {
      const m = token.pattern.exec(rest)
      if (m !== null && (earliest === null || m.index < earliest.index)) {
        earliest = { index: m.index, match: m[0], color: token.color }
      }
    }

    if (!earliest) {
      result += escapeHtml(rest)
      break
    }

    result += escapeHtml(rest.slice(0, earliest.index))
    result += `<span style="color:${earliest.color}">${escapeHtml(earliest.match)}</span>`
    rest = rest.slice(earliest.index + earliest.match.length)
  }

  return result
}

function highlightCode(raw: string): string {
  return raw.split('\n').map(highlightLine).join('\n')
}

function CodeTab({ rawContent }: { rawContent: string }) {
  return (
    <pre
      className="text-xs font-mono text-[#E6EDF3] p-4 overflow-auto h-full leading-5 whitespace-pre-wrap"
      dangerouslySetInnerHTML={{ __html: highlightCode(rawContent) }}
    />
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
      <div className="flex flex-col items-center justify-center h-32 text-[#7D8590] text-sm">
        <span className="text-2xl mb-2">✓</span>
        No warnings found
      </div>
    )
  }

  return (
    <div className="p-4 space-y-4">
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

export function DetailPanel() {
  const [activeTab, setActiveTab] = useState<Tab>('code')
  const { selectedVersion } = useSchemaStore()

  const { data: detail, isLoading } = useQuery({
    queryKey: ['migration', selectedVersion],
    queryFn:  () => client.getMigrationDetail(selectedVersion!),
    enabled:  !!selectedVersion,
  })

  if (isLoading) {
    return (
      <div className="animate-pulse p-4 space-y-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="h-3 bg-[#30363D] rounded w-full" />
        ))}
      </div>
    )
  }

  if (!detail) return null

  return (
    <div className="flex flex-col h-full">
      <div className="px-4 py-3 border-b border-[#30363D]">
        <p className="text-sm font-semibold truncate">{detail.name}</p>
        <p className="text-xs font-mono text-[#7D8590]">{detail.version}</p>
      </div>

      <div className="flex border-b border-[#30363D]">
        {(['code', 'warnings'] as Tab[]).map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`flex-1 py-2 text-xs font-mono uppercase tracking-wider transition-colors ${
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

      <div className="flex-1 overflow-auto">
        {activeTab === 'code'
          ? <CodeTab rawContent={detail.raw_content} />
          : <WarningsTab warnings={detail.warnings} />}
      </div>
    </div>
  )
}
