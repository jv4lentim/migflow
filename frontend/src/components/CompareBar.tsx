import { useQuery } from '@tanstack/react-query'
import { client } from '../api/client'
import { useSchemaStore } from '../store/useSchemaStore'

export function CompareBar() {
  const { selectedVersion, compareTo, setCompareTo } = useSchemaStore()

  const { data: migrations } = useQuery({
    queryKey: ['migrations'],
    queryFn:  client.getMigrations,
  })

  const baseMigration = migrations?.find((m) => m.version === selectedVersion)

  const compareActive =
    !!selectedVersion && !!compareTo && compareTo !== selectedVersion

  const { data: diff, isFetching } = useQuery({
    queryKey: ['diff', selectedVersion, compareTo],
    queryFn:  () => client.getDiff(selectedVersion!, compareTo!),
    enabled:  compareActive,
  })

  return (
    <div className="flex items-center gap-3 px-4 py-2.5 border-b border-[#30363D] shrink-0 bg-[#0D1117]">
      <span className="text-xs font-mono text-[#7D8590] shrink-0 w-12">Base</span>

      <div className="min-w-0 flex-1 max-w-[min(40vw,320px)] text-xs font-mono truncate rounded border border-[#30363D] bg-[#161B22] px-2 py-1 text-[#E6EDF3]">
        {baseMigration
          ? (
              <>
                <span className="text-[#7D8590]">{baseMigration.version}</span>
                <span className="text-[#7D8590]"> · </span>
                <span>{baseMigration.name}</span>
              </>
            )
          : <span className="text-[#7D8590]">Select a migration in the timeline</span>}
      </div>

      <span className="text-xs font-mono text-[#7D8590] shrink-0 w-14">Target</span>

      <select
        value={compareTo ?? ''}
        onChange={(e) => setCompareTo(e.target.value)}
        disabled={!selectedVersion}
        className="bg-[#161B22] border border-[#30363D] text-[#E6EDF3] text-xs font-mono rounded px-2 py-1 min-w-0 flex-1 max-w-[min(40vw,320px)] disabled:opacity-40"
        aria-label="Compare target migration"
      >
        <option value="">None</option>
        {migrations
          ?.filter((m) => m.version !== selectedVersion)
          .map((m) => (
            <option key={m.version} value={m.version}>
              {m.version} — {m.name}
            </option>
          ))}
      </select>

      {compareActive && (
        <span className="text-xs text-[#7D8590] font-mono shrink-0 ml-auto">
          {isFetching ? '…' : `${diff?.changes.length ?? 0} changes`}
        </span>
      )}
    </div>
  )
}
