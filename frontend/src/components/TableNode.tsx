import { memo } from 'react'
import { Handle, Position } from '@xyflow/react'
import type { NodeProps } from '@xyflow/react'
import type { ColumnWithDiff, IndexWithDiff } from '../types/migration'
import { useSchemaStore } from '../store/useSchemaStore'
import {
  HEADER_HEIGHT,
  COLUMN_HEIGHT,
  NODE_BORDER,
  NODE_PADDING_TOP,
  NODE_WIDTH,
} from '../constants/layout'
import { palette } from '../theme/colors'

export { HEADER_HEIGHT, COLUMN_HEIGHT, NODE_WIDTH } from '../constants/layout'

export interface TableNodeData {
  label:        string
  columns:      ColumnWithDiff[]
  indexes:      IndexWithDiff[]
  warningCount: number
  tableStatus?: 'added' | 'removed'
  fkColumns:    string[]
  fkEdgeMap:    Record<string, string>
  isEdgeSelected?: boolean
  isSelected?: boolean
  isCollapsed?: boolean
  [key: string]: unknown
}

const TYPE_ICONS: Record<string, string> = {
  integer:  '#',
  bigint:   '#',
  string:   'A',
  text:     '¶',
  boolean:  '~',
  date:     '◷',
  datetime: '◷',
  decimal:  '∑',
  float:    '∑',
  json:     '{}',
  jsonb:    '{}',
}

function typeIcon(type: string): string {
  return TYPE_ICONS[type] ?? '·'
}

interface ColumnRowProps {
  column:    ColumnWithDiff
  indexes:   IndexWithDiff[]
  fkEdgeId:  string | undefined
  columnIndex: number
}

function ColumnRow({ column, indexes, fkEdgeId, columnIndex }: ColumnRowProps) {
  const { setHighlightedEdgeId } = useSchemaStore()

  const isFk     = !!fkEdgeId
  const status   = column.diffStatus
  const idxEntry = indexes.find((idx) => idx.columns.includes(column.name))
  const indexed  = !!idxEntry
  const idxStatus = idxEntry?.diffStatus

  const rowBg =
    status === 'added'   ? palette.rowAddedBg :
    status === 'removed' ? palette.rowRemovedBg :
    undefined

  const nameColor =
    status === 'removed' ? palette.diffRemoved :
    status === 'added'   ? palette.diffAdded :
    isFk                 ? palette.accent :
    '#E6EDF3'

  const typeColor    = status === 'removed' ? palette.diffRemoved : '#7D8590'
  const lightningColor = idxStatus === 'added'   ? palette.diffAdded :
                       idxStatus === 'removed' ? palette.diffRemoved :
                       palette.warning

  return (
    <div
      className={`flex items-center gap-1.5 px-3 text-xs transition-colors cursor-default box-border ${columnIndex > 0 ? 'border-t border-[#30363D]' : ''} ${!rowBg ? 'hover:bg-[#0D1117]' : ''}`}
      style={{ height: COLUMN_HEIGHT, backgroundColor: rowBg }}
      onMouseEnter={isFk ? () => setHighlightedEdgeId(fkEdgeId) : undefined}
      onMouseLeave={isFk ? () => setHighlightedEdgeId(null) : undefined}
    >
      <span className="w-3 text-center shrink-0 font-mono text-[#7D8590]">
        {status === 'added'   && <span style={{ color: palette.diffAdded }}>+</span>}
        {status === 'removed' && <span style={{ color: palette.diffRemoved }}>−</span>}
        {!status && typeIcon(column.type)}
      </span>

      <span
        className={`flex-1 font-mono truncate ${status === 'removed' ? 'line-through' : ''}`}
        style={{ color: nameColor }}
      >
        {column.name}
      </span>

      {column.type && (
        <span className="font-mono shrink-0 text-[10px]" style={{ color: typeColor }}>
          {column.type}{column.limit ? `(${column.limit})` : ''}
        </span>
      )}

      {indexed  && <span className="shrink-0" style={{ color: lightningColor }} title="indexed">⚡</span>}
      {isFk && !status && <span className="shrink-0" style={{ color: palette.accent }} title="foreign key">⇢</span>}
    </div>
  )
}

export const TableNode = memo(({ data, id }: NodeProps) => {
  const { label, columns, indexes, warningCount, tableStatus, fkColumns, fkEdgeMap, isEdgeSelected, isSelected, isCollapsed } =
    data as TableNodeData

  const isNew     = tableStatus === 'added'
  const isRemoved = tableStatus === 'removed'
  const borderColor = isSelected || isEdgeSelected ? palette.accent
                    : isNew         ? palette.diffAdded
                    : isRemoved     ? palette.diffRemoved
                    : '#30363D'
  const borderWidth = isSelected ? 2 : 1
  const boxShadow   = isSelected ? '0 0 0 3px rgba(88, 166, 255, 0.2)' : undefined
  const headerBg    = isSelected ? '#1a2332' : '#0D1117'

  const { toggleTableCollapsed } = useSchemaStore()

  const handleToggleCollapsed = (e: React.MouseEvent) => {
    e.stopPropagation()
    if (id) toggleTableCollapsed(id)
  }

  const fkSet = new Set(fkColumns ?? [])

  const targetHandleTop = NODE_BORDER + HEADER_HEIGHT / 2

  return (
    <div className="relative cursor-pointer" style={{ width: NODE_WIDTH }}>
      <Handle
        type="target"
        position={Position.Left}
        id="table-target"
        className="!w-2 !h-2 !bg-[#30363D] !border-[#484F58]"
        style={{ top: targetHandleTop, position: 'absolute' }}
      />

      {isCollapsed ? (
        <Handle
          type="source"
          position={Position.Right}
          id="table-source"
          style={{
            top:        targetHandleTop,
            right:      -5,
            position:   'absolute',
            background: palette.accent,
            width:      8,
            height:     8,
            border:     'none',
            borderRadius: '50%',
          }}
        />
      ) : (
        (columns as ColumnWithDiff[]).map((col, idx) => {
          if (!fkSet.has(col.name)) return null
          const handleTop =
            NODE_BORDER +
            HEADER_HEIGHT +
            NODE_PADDING_TOP +
            idx * COLUMN_HEIGHT +
            COLUMN_HEIGHT / 2
          return (
            <Handle
              key={col.name}
              type="source"
              position={Position.Right}
              id={col.name}
              style={{
                top:        handleTop,
                right:      -5,
                position:   'absolute',
                background: palette.accent,
                width:      8,
                height:     8,
                border:     'none',
                borderRadius: '50%',
              }}
            />
          )
        })
      )}

      <div
        className={`bg-[#161B22] border rounded-lg overflow-hidden shadow-lg ${isRemoved ? 'opacity-60' : ''} ${(isSelected || isEdgeSelected) ? 'ring-2 ring-[#58A6FF]' : ''}`}
        style={{ borderColor, borderWidth, boxShadow }}
      >
        <div
          className="flex items-center justify-between px-3 py-2 border-b"
          style={{ borderColor, height: HEADER_HEIGHT, background: headerBg }}
        >
          <span className="font-mono text-sm font-semibold text-[#E6EDF3] truncate">{label}</span>
          <div className="flex items-center gap-1 shrink-0 ml-1">
            <button
              type="button"
              onClick={handleToggleCollapsed}
              className="p-0.5 rounded hover:bg-[#30363D] text-[#7D8590] hover:text-[#E6EDF3] transition-colors"
              aria-label={isCollapsed ? 'Expand table' : 'Collapse table'}
            >
              {isCollapsed ? (
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M6 9l6 6 6-6" /></svg>
              ) : (
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M18 15l-6-6-6 6" /></svg>
              )}
            </button>
            {isNew     && (
              <span
                className="text-[#0D1117] text-[9px] font-bold px-1.5 py-0.5 rounded"
                style={{ backgroundColor: palette.diffAdded }}
              >
                NEW
              </span>
            )}
            {isRemoved && (
              <span
                className="text-white text-[9px] font-bold px-1.5 py-0.5 rounded"
                style={{ backgroundColor: palette.diffRemoved }}
              >
                REMOVED
              </span>
            )}
            {warningCount > 0 && (
              <span
                className="text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full"
                style={{ backgroundColor: palette.diffRemoved }}
              >
                {warningCount}
              </span>
            )}
          </div>
        </div>

        {!isCollapsed && (
        <div>
          {(columns as ColumnWithDiff[]).map((col, idx) => (
            <ColumnRow
              key={col.name}
              column={col}
              indexes={indexes as IndexWithDiff[]}
              fkEdgeId={fkSet.has(col.name) ? (fkEdgeMap ?? {})[col.name] : undefined}
              columnIndex={idx}
            />
          ))}
        </div>
        )}
      </div>
    </div>
  )
})

TableNode.displayName = 'TableNode'
