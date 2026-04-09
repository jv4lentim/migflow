import { structuredPatch } from 'diff'
import type { Schema, Table } from '../types/migration'

function formatColumnRuby(table: Table): string[] {
  return table.columns.map((col) => {
    const options: string[] = []
    if (!col.null) options.push('null: false')
    if (col.default != null) options.push(`default: ${col.default}`)
    if (col.limit != null) options.push(`limit: ${col.limit}`)
    const optsText = options.length > 0 ? `, ${options.join(', ')}` : ''
    const type = col.type || 'string'
    return `    t.${type} "${col.name}"${optsText}`
  })
}

function formatIndexesRuby(table: Table): string[] {
  return table.indexes.map((idx) => {
    const columns = `[${idx.columns.map((column) => `"${column}"`).join(', ')}]`
    const options: string[] = []
    if (idx.name) options.push(`name: "${idx.name}"`)
    if (idx.unique) options.push('unique: true')
    const optsText = options.length > 0 ? `, ${options.join(', ')}` : ''
    return `    t.index ${columns}${optsText}`
  })
}

export function schemaToRubyText(schema?: Schema): string {
  const tables = schema?.tables ?? {}
  const tableNames = Object.keys(tables).sort()

  if (tableNames.length === 0) return ''

  const lines: string[] = []
  for (const tableName of tableNames) {
    const table = tables[tableName]
    if (!table) continue
    lines.push(`  create_table "${tableName}" do |t|`)
    lines.push(...formatColumnRuby(table))
    lines.push(...formatIndexesRuby(table))
    lines.push('  end')
    lines.push('')
  }

  while (lines.length > 0 && lines[lines.length - 1] === '') lines.pop()
  return lines.join('\n')
}

export function buildSchemaPatch(oldSchema?: Schema, newSchema?: Schema): string {
  const oldText = schemaToRubyText(oldSchema)
  const newText = schemaToRubyText(newSchema)
  const patch = structuredPatch('a/schema.rb', 'b/schema.rb', oldText, newText, '', '', {
    context: 1,
  })

  if (patch.hunks.length === 0) return ''

  const hunkBlocks = patch.hunks.map((hunk) => {
    const oldCount = hunk.oldLines ?? 0
    const newCount = hunk.newLines ?? 0
    return [
      `@@ -${hunk.oldStart},${oldCount} +${hunk.newStart},${newCount} @@`,
      ...hunk.lines,
    ].join('\n')
  })

  return [
    'diff --git a/schema.rb b/schema.rb',
    '--- a/schema.rb',
    '+++ b/schema.rb',
    ...hunkBlocks,
    '',
  ].join('\n')
}
