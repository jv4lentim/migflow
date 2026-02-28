import { useMemo, useCallback, useEffect } from 'react'
import { ReactFlow, Background, Controls, MiniMap, useNodesState, useEdgesState } from '@xyflow/react'
import type { Node, Edge } from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import { useQuery } from '@tanstack/react-query'
import { client } from '../api/client'
import { useSchemaStore } from '../store/useSchemaStore'
import { TableNode } from './TableNode'
import type { Table, Warning } from '../types/migration'

const NODE_TYPES = { tableNode: TableNode }

const GRID_COLS     = 4
const NODE_WIDTH    = 280
const NODE_HEIGHT   = 200
const GRID_GAP_X    = 60
const GRID_GAP_Y    = 80

function buildNodes(
  tables: Record<string, Table>,
  warnings: Warning[],
): Node[] {
  const entries = Object.entries(tables)

  return entries.map(([name, table], i) => {
    const col = i % GRID_COLS
    const row = Math.floor(i / GRID_COLS)
    const warningCount = warnings.filter((w) => w.table === name).length

    return {
      id:       name,
      type:     'tableNode',
      position: {
        x: col * (NODE_WIDTH + GRID_GAP_X),
        y: row * (NODE_HEIGHT + GRID_GAP_Y),
      },
      data: {
        label:        name,
        columns:      table.columns,
        indexes:      table.indexes,
        warningCount,
      },
    }
  })
}

function buildEdges(tables: Record<string, Table>): Edge[] {
  const edges: Edge[] = []
  const tableNames    = new Set(Object.keys(tables))

  for (const [tableName, table] of Object.entries(tables)) {
    for (const col of table.columns) {
      if (!col.name.endsWith('_id')) continue

      const target = col.name.replace(/_id$/, 's')
      const targetSingular = col.name.replace(/_id$/, '')

      const resolvedTarget = tableNames.has(target)
        ? target
        : tableNames.has(targetSingular)
          ? targetSingular
          : null

      if (!resolvedTarget) continue

      edges.push({
        id:     `${tableName}-${col.name}-${resolvedTarget}`,
        source: tableName,
        target: resolvedTarget,
        style:  { stroke: '#30363D', strokeWidth: 1 },
        animated: false,
      })
    }
  }

  return edges
}

function EmptyState() {
  return (
    <div className="flex flex-col items-center justify-center h-full text-[#7D8590]">
      <p className="text-4xl mb-4">⬡</p>
      <p className="text-sm">Select a migration from the timeline</p>
    </div>
  )
}

export function SchemaCanvas() {
  const { selectedVersion } = useSchemaStore()

  const { data: detail } = useQuery({
    queryKey: ['migration', selectedVersion],
    queryFn:  () => client.getMigrationDetail(selectedVersion!),
    enabled:  !!selectedVersion,
  })

  const { data: warnings } = useQuery({
    queryKey: ['warnings'],
    queryFn:  client.getWarnings,
  })

  const initialNodes = useMemo(() => {
    if (!detail?.schema?.tables) return []
    return buildNodes(detail.schema.tables, warnings ?? [])
  }, [detail, warnings])

  const initialEdges = useMemo(() => {
    if (!detail?.schema?.tables) return []
    return buildEdges(detail.schema.tables)
  }, [detail])

  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes)
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges)

  useEffect(() => { setNodes(initialNodes) }, [initialNodes, setNodes])
  useEffect(() => { setEdges(initialEdges) }, [initialEdges, setEdges])

  const onInit = useCallback(() => {}, [])

  if (!selectedVersion) return <EmptyState />

  return (
    <ReactFlow
      nodes={nodes}
      edges={edges}
      onNodesChange={onNodesChange}
      onEdgesChange={onEdgesChange}
      onInit={onInit}
      nodeTypes={NODE_TYPES}
      fitView
      className="bg-[#0D1117]"
    >
      <Background color="#30363D" gap={24} size={1} />
      <Controls className="[&>button]:bg-[#161B22] [&>button]:border-[#30363D] [&>button]:text-[#E6EDF3]" />
      <MiniMap
        nodeColor="#30363D"
        maskColor="rgba(13,17,23,0.8)"
        className="border border-[#30363D] rounded"
      />
    </ReactFlow>
  )
}
