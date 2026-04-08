import { useMemo, useCallback, useEffect, useRef, type Dispatch, type SetStateAction } from 'react'
import {
  ReactFlow,
  Background,
  Controls,
  useNodesState,
  useEdgesState,
  useReactFlow,
  type Node,
  type Edge,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import { useQuery } from '@tanstack/react-query'
import { client } from '../api/client'
import { useSchemaStore } from '../store/useSchemaStore'
import { TableNode, type TableNodeData } from './TableNode'
import { NODE_WIDTH, nodeHeight, HEADER_HEIGHT } from '../constants/layout'
import { RelationshipEdge } from './RelationshipEdge'
import type { Table, ColumnWithDiff, IndexWithDiff, DiffInfo, Warning } from '../types/migration'
import { diffInfoFromApi, emptyDiffInfo } from '../utils/parseMigrationChanges'
import { schemasToDiffInfo } from '../utils/schemaDiffToDiffInfo'

const NODE_TYPES = { tableNode:     TableNode }
const EDGE_TYPES = { relationship:  RelationshipEdge }

function warningDedupeKey(warning: Warning): string {
  return [
    warning.rule,
    warning.severity,
    warning.table,
    warning.column ?? '',
    warning.message,
  ].join('::')
}

function dedupeWarnings(warnings: Warning[]): Warning[] {
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

function mergeScopedWarnings(
  baseWarnings:   Warning[] | undefined,
  targetWarnings: Warning[] | undefined,
  includeTarget:  boolean,
): Warning[] {
  const combined = includeTarget
    ? [...(baseWarnings ?? []), ...(targetWarnings ?? [])]
    : (baseWarnings ?? [])

  return dedupeWarnings(combined)
}

function countWarningsByTable(warnings: Warning[]): Map<string, number> {
  const counts = new Map<string, number>()
  for (const warning of warnings) {
    counts.set(warning.table, (counts.get(warning.table) ?? 0) + 1)
  }
  return counts
}

const H_GAP     = 80
const V_GAP     = 80
const GRID_COLS = 4

interface RawEdgeResult {
  rawEdges:     Edge[]
  fkColumnsMap: Map<string, string[]>
}

function buildRawEdges(
  tables:   Record<string, Table>,
  diffInfo: DiffInfo,
): RawEdgeResult {
  const rawEdges:     Edge[]                   = []
  const fkColumnsMap: Map<string, string[]>    = new Map()
  const tableNames    = new Set(Object.keys(tables))

  for (const [tableName, table] of Object.entries(tables)) {
    for (const col of table.columns) {
      if (!col.name.endsWith('_id')) continue

      const prefix   = col.name.replace(/_id$/, '')
      const target   = tableNames.has(`${prefix}s`) ? `${prefix}s`
                     : tableNames.has(prefix)        ? prefix
                     : null

      if (!target) continue

      const addedCols   = diffInfo.addedColumns.get(tableName)  ?? []
      const removedCols = diffInfo.removedColumns.get(tableName) ?? []
      const isAdded     = diffInfo.addedTables.has(tableName) || addedCols.includes(col.name)
      const isRemoved   = removedCols.includes(col.name)

      const list = fkColumnsMap.get(tableName) ?? []
      list.push(col.name)
      fkColumnsMap.set(tableName, list)

      rawEdges.push({
        id:           `${tableName}-${col.name}-${target}`,
        source:       tableName,
        target,
        sourceHandle: col.name,
        targetHandle: 'table-target',
        type:         'relationship',
        animated:     isAdded,
        data: {
          diffAdded:   isAdded,
          diffRemoved: isRemoved,
          fkColumn:    col.name,
        },
      })
    }
  }

  return { rawEdges, fkColumnsMap }
}

function calculateOffset(index: number, count: number): number {
  if (count === 1) return 20
  const spread = 20
  return (index - (count - 1) / 2) * spread + 20
}

function applyEdgeCurvature(edges: Edge[]): Edge[] {
  const edgePairs = new Map<string, Edge[]>()
  edges.forEach((edge) => {
    const pairKey = [edge.source, edge.target].sort().join('__')
    if (!edgePairs.has(pairKey)) edgePairs.set(pairKey, [])
    edgePairs.get(pairKey)!.push(edge)
  })

  const result: Edge[] = []
  edgePairs.forEach((group) => {
    const count = group.length
    group.forEach((edge, index) => {
      const offset = calculateOffset(index, count)
      result.push({
        ...edge,
        type: 'relationship',
        data: {
          ...(edge.data ?? {}),
          pathOptions: { borderRadius: 12, offset },
        },
      })
    })
  })
  return result
}

function buildNodes(
  tables:         Record<string, Table>,
  warningCountByTable: Map<string, number>,
  diffInfo:       DiffInfo,
  fkColumnsMap:   Map<string, string[]>,
  selectedEdgeId: string | null,
  selectedTableId: string | null,
  collapsedTables: Set<string>,
  edges:          Edge[],
): Node[] {
  const selectedNodeIds = new Set<string>()
  if (selectedEdgeId) {
    const edge = edges.find((e) => e.id === selectedEdgeId)
    if (edge) {
      selectedNodeIds.add(edge.source)
      selectedNodeIds.add(edge.target)
    }
  }

  const tableNames = new Set(Object.keys(tables))
  const entries: [string, Table | null][] = [...Object.entries(tables)]

  for (const dropped of diffInfo.removedTables) {
    if (!tables[dropped]) entries.push([dropped, null])
  }

  let colInRow     = 0
  let currentY     = 0
  let rowMaxHeight = 0

  return entries.map(([name, table]) => {
    const isNewTable     = diffInfo.addedTables.has(name)
    const isRemovedTable = diffInfo.removedTables.has(name)
    const addedCols      = diffInfo.addedColumns.get(name)   ?? []
    const removedCols    = diffInfo.removedColumns.get(name) ?? []
    const addedIdxCols   = diffInfo.addedIndexColumns.get(name)   ?? []
    const removedIdxCols = diffInfo.removedIndexColumns.get(name) ?? []

    const baseColumns: ColumnWithDiff[] = (table?.columns ?? []).map((col) => ({
      ...col,
      diffStatus: (isNewTable || addedCols.includes(col.name)) ? 'added' : undefined,
    }))

    const ghostColumns: ColumnWithDiff[] = removedCols
      .filter((c) => !baseColumns.some((b) => b.name === c))
      .map((colName) => ({
        name: colName, type: '', null: true, default: null, diffStatus: 'removed' as const,
      }))

    const allColumns = [...baseColumns, ...ghostColumns]

    const allIndexes: IndexWithDiff[] = (table?.indexes ?? []).map((idx) => ({
      ...idx,
      diffStatus: idx.columns.some((c) => addedIdxCols.includes(c))   ? 'added'
               : idx.columns.some((c) => removedIdxCols.includes(c))  ? 'removed'
               : undefined,
    }))

    const fkColNames = fkColumnsMap.get(name) ?? []
    const fkEdgeMap: Record<string, string>  = {}
    for (const colName of fkColNames) {
      const prefix       = colName.replace(/_id$/, '')
      const targetTable  = tableNames.has(`${prefix}s`) ? `${prefix}s`
                         : tableNames.has(prefix)        ? prefix
                         : null
      if (targetTable) fkEdgeMap[colName] = `${name}-${colName}-${targetTable}`
    }

    const warningCount = warningCountByTable.get(name) ?? 0
    const tableStatus  = isNewTable ? 'added' : isRemovedTable ? 'removed' : undefined
    const isCollapsed   = collapsedTables.has(name)

    const height = isCollapsed ? HEADER_HEIGHT : nodeHeight(allColumns.length)
    const x      = colInRow * (NODE_WIDTH + H_GAP)
    const y      = currentY

    rowMaxHeight = Math.max(rowMaxHeight, height)
    colInRow++

    if (colInRow >= GRID_COLS) {
      colInRow     = 0
      currentY    += rowMaxHeight + V_GAP
      rowMaxHeight = 0
    }

    return {
      id:       name,
      type:     'tableNode',
      position: { x, y },
      style:    { transition: 'transform 250ms ease' },
      data: {
        label:        name,
        columns:      allColumns,
        indexes:      allIndexes,
        warningCount,
        tableStatus,
        fkColumns:    fkColNames,
        fkEdgeMap,
        isEdgeSelected: selectedNodeIds.has(name),
        isSelected:     selectedTableId === name,
        isCollapsed,
      } satisfies TableNodeData,
    }
  })
}

interface FitViewManagerProps {
  computedNodes: Node[]
  computedEdges: Edge[]
  setNodes: Dispatch<SetStateAction<Node[]>>
  setEdges: (edges: Edge[]) => void
  fitEpoch: string
}

function FitViewManager({ computedNodes, computedEdges, setNodes, setEdges, fitEpoch }: FitViewManagerProps) {
  const { fitView } = useReactFlow()
  const pendingFitView = useRef(false)

  useEffect(() => {
    pendingFitView.current = true
  }, [fitEpoch])

  useEffect(() => {
    if (pendingFitView.current) {
      setNodes(computedNodes)
    } else {
      setNodes((prev: Node[]) => {
        const positionMap = new Map(prev.map((n: Node) => [n.id, n.position]))
        return computedNodes.map((node) => ({
          ...node,
          position: positionMap.get(node.id) ?? node.position,
        }))
      })
    }
    setEdges(computedEdges)

    if (!pendingFitView.current || computedNodes.length === 0) return
    pendingFitView.current = false

    const changedIds = computedNodes
      .filter((n) => {
        const d = n.data as TableNodeData
        return d.tableStatus === 'added'
            || d.tableStatus === 'removed'
            || (d.columns as ColumnWithDiff[]).some((c) => c.diffStatus)
      })
      .map((n) => ({ id: n.id }))

    requestAnimationFrame(() => {
      fitView(
        changedIds.length > 0
          ? { nodes: changedIds, duration: 500, padding: 0.2 }
          : { duration: 500, padding: 0.1 },
      )
    })
  }, [computedNodes, computedEdges, fitView, setEdges, setNodes])

  return null
}

interface CanvasInnerProps {
  computedNodes: Node[]
  computedEdges: Edge[]
  fitEpoch: string
}

function CanvasInner({ computedNodes, computedEdges, fitEpoch }: CanvasInnerProps) {
  const { setHighlightedEdgeId, setSelectedTableId, setSelectedEdgeId } = useSchemaStore()

  const [nodes, setNodes, onNodesChange] = useNodesState(computedNodes)
  const [edges, setEdges, onEdgesChange] = useEdgesState(computedEdges)

  const onNodeClick  = useCallback((_: React.MouseEvent, node: Node) => {
    setSelectedTableId(node.id)
    setSelectedEdgeId(null)
  }, [setSelectedTableId, setSelectedEdgeId])
  const onPaneClick  = useCallback(() => {
    setSelectedEdgeId(null)
    setSelectedTableId(null)
  }, [setSelectedEdgeId, setSelectedTableId])
  const onEdgeClick  = useCallback((_: React.MouseEvent, edge: Edge) => {
    setSelectedEdgeId(edge.id)
    setSelectedTableId(null)
  }, [setSelectedEdgeId, setSelectedTableId])
  const onEdgeEnter  = useCallback((_: React.MouseEvent, edge: Edge) => setHighlightedEdgeId(edge.id), [setHighlightedEdgeId])
  const onEdgeLeave  = useCallback(() => setHighlightedEdgeId(null), [setHighlightedEdgeId])

  return (
    <ReactFlow
      nodes={nodes}
      edges={edges}
      onNodesChange={onNodesChange}
      onEdgesChange={onEdgesChange}
      nodeTypes={NODE_TYPES}
      edgeTypes={EDGE_TYPES}
      onNodeClick={onNodeClick}
      onPaneClick={onPaneClick}
      onEdgeClick={onEdgeClick}
      onEdgeMouseEnter={onEdgeEnter}
      onEdgeMouseLeave={onEdgeLeave}
      defaultEdgeOptions={{ type: 'relationship' }}
      fitView
      className="bg-[#0D1117]"
    >
      <FitViewManager
        computedNodes={computedNodes}
        computedEdges={computedEdges}
        setNodes={setNodes}
        setEdges={setEdges}
        fitEpoch={fitEpoch}
      />
      <Background color="#30363D" gap={24} size={1} />
      <Controls />
    </ReactFlow>
  )
}

function EmptyState({ message }: { message?: string }) {
  return (
    <div className="flex flex-col items-center justify-center h-full text-[#7D8590] px-6 text-center">
      <p className="text-4xl mb-4">⬡</p>
      <p className="text-sm max-w-sm">
        {message ?? 'Select a migration from the timeline'}
      </p>
    </div>
  )
}

export function SchemaCanvas() {
  const {
    selectedVersion,
    selectedEdgeId,
    selectedTableId,
    collapsedTables,
    compareTo,
  } = useSchemaStore()

  const comparePairValid =
    !!selectedVersion
    && !!compareTo
    && compareTo !== selectedVersion

  const { data: detailBase, isPending: loadingBase } = useQuery({
    queryKey: ['migration', selectedVersion],
    queryFn:  () => client.getMigrationDetail(selectedVersion!),
    enabled:  !!selectedVersion,
  })

  const { data: detailTarget, isPending: loadingTarget } = useQuery({
    queryKey: ['migration', compareTo],
    queryFn:  () => client.getMigrationDetail(compareTo!),
    enabled:  comparePairValid,
  })

  const scopedWarnings = useMemo(
    () => mergeScopedWarnings(detailBase?.warnings, detailTarget?.warnings, comparePairValid),
    [detailBase?.warnings, detailTarget?.warnings, comparePairValid],
  )

  const activeDetail = comparePairValid ? detailTarget : detailBase
  const diff = detailBase?.diff
  const diffInfo = useMemo(() => {
    if (comparePairValid && detailTarget && detailBase) {
      return schemasToDiffInfo(detailBase.schema_after.tables, detailTarget.schema_after.tables)
    }
    if (!diff) return emptyDiffInfo()
    return diffInfoFromApi(diff)
  }, [comparePairValid, detailTarget, detailBase, diff])

  const warningCountByTable = useMemo(() => {
    return countWarningsByTable(scopedWarnings)
  }, [scopedWarnings])

  const { computedNodes, computedEdges } = useMemo(() => {
    if (!activeDetail?.schema_after?.tables) return { computedNodes: [], computedEdges: [] }

    const { rawEdges, fkColumnsMap } = buildRawEdges(activeDetail.schema_after.tables, diffInfo)
    const collapsedSet = collapsedTables
    const edgesWithHandles = rawEdges.map((edge) => {
      const sourceCollapsed = collapsedSet.has(edge.source)
      return {
        ...edge,
        sourceHandle: sourceCollapsed ? 'table-source' : edge.sourceHandle,
      }
    })
    const edges = applyEdgeCurvature(edgesWithHandles).map((edge) => ({
      ...edge,
      animated: selectedEdgeId === edge.id,
    }))
    const nodes = buildNodes(
      activeDetail.schema_after.tables,
      warningCountByTable,
      diffInfo,
      fkColumnsMap,
      selectedEdgeId,
      selectedTableId,
      collapsedTables,
      edges,
    )

    return { computedNodes: nodes, computedEdges: edges }
  }, [activeDetail, diffInfo, selectedEdgeId, selectedTableId, collapsedTables, warningCountByTable])

  const fitEpoch = comparePairValid
    ? `cmp:${selectedVersion}:${compareTo}`
    : `m:${selectedVersion ?? ''}`

  if (!selectedVersion) {
    return <EmptyState />
  }

  if (loadingBase || (comparePairValid && loadingTarget)) {
    return (
      <div className="flex items-center justify-center h-full text-[#7D8590] text-sm font-mono">
        Loading schemas…
      </div>
    )
  }

  return (
    <CanvasInner
      computedNodes={computedNodes}
      computedEdges={computedEdges}
      fitEpoch={fitEpoch}
    />
  )
}
