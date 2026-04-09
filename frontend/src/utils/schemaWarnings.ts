import type { Warning } from '../types/migration'

function warningDedupeKey(warning: Warning): string {
  return [
    warning.rule,
    warning.severity,
    warning.table,
    warning.column ?? '',
    warning.message,
  ].join('::')
}

export function dedupeWarnings(warnings: Warning[]): Warning[] {
  const seen = new Set<string>()
  const unique: Warning[] = []

  for (const warning of warnings) {
    const key = warningDedupeKey(warning)
    if (seen.has(key)) continue
    seen.add(key)
    unique.push(warning)
  }

  return unique
}

export function mergeScopedWarnings(
  baseWarnings: Warning[] | undefined,
  targetWarnings: Warning[] | undefined,
  includeTarget: boolean,
): Warning[] {
  const combined = includeTarget
    ? [...(baseWarnings ?? []), ...(targetWarnings ?? [])]
    : (baseWarnings ?? [])

  return dedupeWarnings(combined)
}

export function countWarningsByTable(warnings: Warning[]): Map<string, number> {
  const counts = new Map<string, number>()
  for (const warning of warnings) {
    counts.set(warning.table, (counts.get(warning.table) ?? 0) + 1)
  }
  return counts
}
