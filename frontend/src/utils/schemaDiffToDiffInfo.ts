import type { DiffInfo, Index, Table } from '../types/migration'
import { emptyDiffInfo } from './parseMigrationChanges'

function indexKey(idx: Index): string {
  return idx.name || idx.columns.join('_')
}

function pushColumn(map: Map<string, string[]>, table: string, column: string) {
  const list = map.get(table) ?? []
  list.push(column)
  map.set(table, list)
}

/** Structural diff between two schema snapshots (aligned with Ruby DiffBuilder). */
export function schemasToDiffInfo(
  fromTables: Record<string, Table> | undefined,
  toTables:   Record<string, Table> | undefined,
): DiffInfo {
  if (!fromTables || !toTables) return emptyDiffInfo()

  const fromKeys = new Set(Object.keys(fromTables))
  const toKeys   = new Set(Object.keys(toTables))

  const addedTables:   Set<string>       = new Set()
  const removedTables: Set<string>       = new Set()
  const addedColumns:   Map<string, string[]> = new Map()
  const removedColumns: Map<string, string[]> = new Map()
  const addedIndexColumns:   Map<string, string[]> = new Map()
  const removedIndexColumns: Map<string, string[]> = new Map()

  for (const k of toKeys) {
    if (!fromKeys.has(k)) addedTables.add(k)
  }
  for (const k of fromKeys) {
    if (!toKeys.has(k)) removedTables.add(k)
  }

  for (const table of fromKeys) {
    if (!toKeys.has(table)) continue

    const fromT = fromTables[table]
    const toT   = toTables[table]

    const fromColNames = fromT.columns.map((c) => c.name)
    const toColNames   = toT.columns.map((c) => c.name)
    const fromSet      = new Set(fromColNames)
    const toSet        = new Set(toColNames)

    const added = toColNames.filter((c) => !fromSet.has(c))
    const removed = fromColNames.filter((c) => !toSet.has(c))
    if (added.length) addedColumns.set(table, added)
    if (removed.length) removedColumns.set(table, removed)

    const fromIdxMap = new Map(fromT.indexes.map((i) => [indexKey(i), i] as const))
    const toIdxMap   = new Map(toT.indexes.map((i) => [indexKey(i), i] as const))

    const fromIdxKeys = new Set(fromIdxMap.keys())
    const toIdxKeys   = new Set(toIdxMap.keys())

    for (const k of toIdxKeys) {
      if (fromIdxKeys.has(k)) continue
      const idx = toIdxMap.get(k)!
      for (const col of idx.columns) pushColumn(addedIndexColumns, table, col)
    }

    for (const k of fromIdxKeys) {
      if (toIdxKeys.has(k)) continue
      const idx = fromIdxMap.get(k)!
      for (const col of idx.columns) pushColumn(removedIndexColumns, table, col)
    }
  }

  return {
    addedTables,
    removedTables,
    addedColumns,
    removedColumns,
    addedIndexColumns,
    removedIndexColumns,
  }
}
