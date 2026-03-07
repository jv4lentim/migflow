import type { DiffInfo, MigrationDiff } from '../types/migration'

function matchAll(content: string, pattern: RegExp): RegExpExecArray[] {
  const results: RegExpExecArray[] = []
  const re = new RegExp(pattern.source, pattern.flags.includes('g') ? pattern.flags : pattern.flags + 'g')
  let m: RegExpExecArray | null
  while ((m = re.exec(content)) !== null) results.push(m)
  return results
}

function pushTo(map: Map<string, string[]>, key: string, value: string) {
  const list = map.get(key) ?? []
  list.push(value)
  map.set(key, list)
}

export function emptyDiffInfo(): DiffInfo {
  return {
    addedTables:       new Set(),
    removedTables:     new Set(),
    addedColumns:      new Map(),
    removedColumns:    new Map(),
    addedIndexColumns: new Map(),
    removedIndexColumns: new Map(),
  }
}

export function diffInfoFromApi(diff: MigrationDiff): DiffInfo {
  const addedColumns:   Map<string, string[]> = new Map()
  const removedColumns: Map<string, string[]> = new Map()

  for (const [table, changes] of Object.entries(diff.modified_tables)) {
    if (changes.added_columns.length)   addedColumns.set(table, changes.added_columns)
    if (changes.removed_columns.length) removedColumns.set(table, changes.removed_columns)
  }

  return {
    addedTables:         new Set(diff.added_tables),
    removedTables:       new Set(diff.removed_tables),
    addedColumns,
    removedColumns,
    addedIndexColumns:   new Map(),
    removedIndexColumns: new Map(),
  }
}

export function parseMigrationChanges(rawContent: string): DiffInfo {
  const info = emptyDiffInfo()

  for (const m of matchAll(rawContent, /create_table[( ]+[:"'](\w+)/)) {
    info.addedTables.add(m[1])
  }

  for (const m of matchAll(rawContent, /drop_table[( ]+[:"'](\w+)/)) {
    info.removedTables.add(m[1])
  }

  for (const m of matchAll(rawContent, /add_column\s*[(\s][\s:"']*(\w+)[\s:"']*,\s*[:"'](\w+)/)) {
    pushTo(info.addedColumns, m[1], m[2])
  }

  for (const m of matchAll(rawContent, /remove_column\s*[(\s][\s:"']*(\w+)[\s:"']*,\s*[:"'](\w+)/)) {
    pushTo(info.removedColumns, m[1], m[2])
  }

  for (const m of matchAll(rawContent, /add_index[( ]+[:"'](\w+)[:"']?,\s*[:"'](\w+)/)) {
    pushTo(info.addedIndexColumns, m[1], m[2])
  }

  for (const m of matchAll(rawContent, /remove_index[( ]+[:"'](\w+)[:"']?,\s*(?:column:\s*)?[:"'](\w+)/)) {
    pushTo(info.removedIndexColumns, m[1], m[2])
  }

  return info
}
