import { useQuery } from '@tanstack/react-query'
import { client } from '../api/client'
import { useSchemaStore } from '../store/useSchemaStore'
import type { Migration } from '../types/migration'

const MIGRATION_COLORS: Record<string, string> = {
  create: '#58A6FF',
  add:    '#3FB950',
  remove: '#F85149',
  drop:   '#F85149',
  change: '#D29922',
  rename: '#D29922',
}

function migrationColor(name: string): string {
  const lower = name.toLowerCase()
  for (const [keyword, color] of Object.entries(MIGRATION_COLORS)) {
    if (lower.startsWith(keyword)) return color
  }
  return '#7D8590'
}

function formatVersion(version: string): string {
  if (version.length < 14) return version
  const y  = version.slice(0, 4)
  const mo = version.slice(4, 6)
  const d  = version.slice(6, 8)
  const h  = version.slice(8, 10)
  const mi = version.slice(10, 12)
  return `${y}-${mo}-${d} ${h}:${mi}`
}

function MigrationSkeleton() {
  return (
    <div className="animate-pulse px-4 py-3 border-b border-[#30363D]">
      <div className="flex items-center gap-3">
        <div className="w-2 h-2 rounded-full bg-[#30363D]" />
        <div className="flex-1 space-y-1.5">
          <div className="h-3 bg-[#30363D] rounded w-3/4" />
          <div className="h-2.5 bg-[#30363D] rounded w-1/2" />
        </div>
      </div>
    </div>
  )
}

interface MigrationItemProps {
  migration: Migration
  isSelected: boolean
  onSelect: (version: string) => void
}

function MigrationItem({ migration, isSelected, onSelect }: MigrationItemProps) {
  const color = migrationColor(migration.name)

  return (
    <button
      onClick={() => onSelect(migration.version)}
      className={`w-full text-left px-4 py-3 border-b border-[#30363D] transition-colors duration-150 hover:bg-[#161B22] flex items-start gap-3 ${
        isSelected ? 'bg-[#161B22] border-l-2 border-l-[#58A6FF]' : ''
      }`}
    >
      <span
        className="mt-1 w-2 h-2 rounded-full shrink-0"
        style={{ backgroundColor: color }}
      />
      <div className="flex-1 min-w-0">
        <p className="text-xs font-mono text-[#7D8590] truncate">
          {formatVersion(migration.version)}
        </p>
        <p className="text-sm text-[#E6EDF3] truncate mt-0.5">{migration.name}</p>
        <p className="text-xs text-[#7D8590] truncate mt-0.5">{migration.summary}</p>
      </div>
    </button>
  )
}

export function Timeline() {
  const { data: migrations, isLoading } = useQuery({
    queryKey: ['migrations'],
    queryFn: client.getMigrations,
  })

  const { selectedVersion, selectMigration } = useSchemaStore()

  if (isLoading) {
    return (
      <div>
        {Array.from({ length: 8 }).map((_, i) => (
          <MigrationSkeleton key={i} />
        ))}
      </div>
    )
  }

  if (!migrations?.length) {
    return (
      <div className="flex items-center justify-center h-32 text-[#7D8590] text-sm">
        No migrations found
      </div>
    )
  }

  return (
    <div>
      <div className="px-4 py-3 text-xs font-mono text-[#7D8590] uppercase tracking-widest border-b border-[#30363D]">
        Migrations ({migrations.length})
      </div>
      {[...migrations].reverse().map((migration) => (
        <MigrationItem
          key={migration.version}
          migration={migration}
          isSelected={selectedVersion === migration.version}
          onSelect={selectMigration}
        />
      ))}
    </div>
  )
}
