import type { DiffInfo } from '../types/migration'

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

export function parseMigrationChanges(rawContent: string): DiffInfo {
  const info = emptyDiffInfo()

  for (const m of matchAll(rawContent, /create_table[( ]+[:"'](\w+)/)) {
    info.addedTables.add(m[1])
  }

  for (const m of matchAll(rawContent, /drop_table[( ]+[:"'](\w+)/)) {
    info.removedTables.add(m[1])
  }

  for (const m of matchAll(rawContent, /add_column[( ]+[:"'](\w+)[:"']?,\s*[:"'](\w+)/)) {
    pushTo(info.addedColumns, m[1], m[2])
  }

  for (const m of matchAll(rawContent, /remove_column[( ]+[:"'](\w+)[:"']?,\s*[:"'](\w+)/)) {
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
