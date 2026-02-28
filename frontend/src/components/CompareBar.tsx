import { useQuery } from '@tanstack/react-query'
import { client } from '../api/client'
import { useSchemaStore } from '../store/useSchemaStore'

export function CompareBar() {
  const { compareFrom, compareTo, setCompareFrom, setCompareTo } = useSchemaStore()

  const { data: migrations } = useQuery({
    queryKey: ['migrations'],
    queryFn:  client.getMigrations,
  })

  const { data: diff, refetch: runDiff, isFetching } = useQuery({
    queryKey: ['diff', compareFrom, compareTo],
    queryFn:  () => client.getDiff(compareFrom!, compareTo!),
    enabled:  false,
  })

  const canCompare = !!compareFrom && !!compareTo && compareFrom !== compareTo

  return (
    <div className="flex items-center gap-3 px-4 h-full">
      <span className="text-xs font-mono text-[#7D8590] shrink-0">Compare</span>

      <select
        value={compareFrom ?? ''}
        onChange={(e) => setCompareFrom(e.target.value)}
        className="bg-[#161B22] border border-[#30363D] text-[#E6EDF3] text-xs font-mono rounded px-2 py-1 flex-1"
      >
        <option value="">From...</option>
        {migrations?.map((m) => (
          <option key={m.version} value={m.version}>
            {m.version} — {m.name}
          </option>
        ))}
      </select>

      <span className="text-[#7D8590] text-xs">→</span>

      <select
        value={compareTo ?? ''}
        onChange={(e) => setCompareTo(e.target.value)}
        className="bg-[#161B22] border border-[#30363D] text-[#E6EDF3] text-xs font-mono rounded px-2 py-1 flex-1"
      >
        <option value="">To...</option>
        {migrations?.map((m) => (
          <option key={m.version} value={m.version}>
            {m.version} — {m.name}
          </option>
        ))}
      </select>

      <button
        onClick={() => runDiff()}
        disabled={!canCompare || isFetching}
        className="bg-[#58A6FF] text-[#0D1117] text-xs font-semibold px-3 py-1 rounded transition-opacity disabled:opacity-40 shrink-0"
      >
        {isFetching ? 'Loading...' : 'Compare'}
      </button>

      {diff && (
        <span className="text-xs text-[#7D8590] font-mono shrink-0">
          {diff.changes.length} changes
        </span>
      )}
    </div>
  )
}
