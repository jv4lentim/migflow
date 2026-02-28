import { memo } from 'react'
import type { NodeProps } from '@xyflow/react'
import type { Column, Index } from '../types/migration'

export interface TableNodeData {
  label: string
  columns: Column[]
  indexes: Index[]
  warningCount: number
  [key: string]: unknown
}

function columnIcon(type: string): string {
  const map: Record<string, string> = {
    integer: '#',
    bigint:  '#',
    string:  'A',
    text:    '¶',
    boolean: '~',
    date:    '◷',
    datetime:'◷',
    decimal: '∑',
    float:   '∑',
    json:    '{}',
    jsonb:   '{}',
  }
  return map[type] ?? '·'
}

function isIndexed(colName: string, indexes: Index[]): boolean {
  return indexes.some((idx) => idx.columns.includes(colName))
}

function isForeignKey(colName: string): boolean {
  return colName.endsWith('_id')
}

interface ColumnRowProps {
  column: Column
  indexes: Index[]
}

function ColumnRow({ column, indexes: idxs }: ColumnRowProps) {
  const indexed = isIndexed(column.name, idxs)
  const fk      = isForeignKey(column.name)

  return (
    <div className="flex items-center gap-2 px-3 py-1 text-xs hover:bg-[#0D1117] transition-colors">
      <span className="text-[#7D8590] font-mono w-3 text-center shrink-0">
        {columnIcon(column.type)}
      </span>
      <span className={`flex-1 font-mono ${fk ? 'text-[#58A6FF]' : 'text-[#E6EDF3]'}`}>
        {column.name}
      </span>
      <span className="text-[#7D8590] font-mono">
        {column.type}{column.limit ? `(${column.limit})` : ''}
      </span>
      {indexed && <span className="text-[#D29922]" title="indexed">⚡</span>}
      {fk      && <span className="text-[#58A6FF]" title="foreign key">⇢</span>}
    </div>
  )
}

export const TableNode = memo(({ data }: NodeProps) => {
  const { label, columns, indexes, warningCount } = data as TableNodeData

  return (
    <div className="bg-[#161B22] border border-[#30363D] rounded-lg overflow-hidden shadow-lg min-w-[200px] max-w-[280px]">
      <div className="flex items-center justify-between px-3 py-2 bg-[#0D1117] border-b border-[#30363D]">
        <span className="font-mono text-sm font-semibold text-[#E6EDF3]">{label}</span>
        {warningCount > 0 && (
          <span className="bg-[#F85149] text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full">
            {warningCount}
          </span>
        )}
      </div>
      <div className="divide-y divide-[#30363D]">
        {(columns as Column[]).map((col) => (
          <ColumnRow key={col.name} column={col} indexes={indexes as Index[]} />
        ))}
      </div>
    </div>
  )
})

TableNode.displayName = 'TableNode'
