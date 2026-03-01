import {
  BaseEdge,
  EdgeLabelRenderer,
  getSmoothStepPath,
  type EdgeProps,
} from '@xyflow/react'
import { useSchemaStore } from '../store/useSchemaStore'

export interface RelationshipEdgeData {
  diffAdded:   boolean
  diffRemoved: boolean
  fkColumn:    string
  pathOptions?: { borderRadius: number; offset: number }
  [key: string]: unknown
}

export function RelationshipEdge({
  id,
  source,
  target,
  sourceX,
  sourceY,
  targetX,
  targetY,
  sourcePosition,
  targetPosition,
  data,
}: EdgeProps) {
  const { highlightedEdgeId, selectedTableId, selectedEdgeId } = useSchemaStore()

  const d              = (data ?? {}) as RelationshipEdgeData
  const isHovered      = highlightedEdgeId === id
  const isEdgeSelected = selectedEdgeId === id
  const isTableFlow    = selectedTableId === source || selectedTableId === target
  const isFlow         = isEdgeSelected || isTableFlow
  const showLabel      = (isHovered || isFlow) && d.fkColumn

  const strokeColor = d.diffAdded    ? '#3FB950'
                    : d.diffRemoved  ? '#F85149'
                    : (isHovered || isFlow) ? '#58A6FF'
                    : '#444C56'

  const strokeWidth = isEdgeSelected ? 2.5 : (isHovered || isTableFlow) ? 2 : 1.5
  const pathOpts    = d.pathOptions ?? { borderRadius: 12, offset: 20 }

  const [edgePath, labelX, labelY] = getSmoothStepPath({
    sourceX,
    sourceY,
    targetX,
    targetY,
    sourcePosition,
    targetPosition,
    borderRadius: pathOpts.borderRadius,
    offset:       pathOpts.offset,
  })

  const edgeClass = isFlow && !d.diffAdded && !d.diffRemoved ? 'edge-flow' : ''

  return (
    <>
      <BaseEdge
        id={id}
        path={edgePath}
        className={edgeClass}
        style={{
          stroke:      strokeColor,
          strokeWidth,
          ...(d.diffRemoved ? { strokeDasharray: '5 5' } : {}),
        }}
      />

      {showLabel && (
        <EdgeLabelRenderer>
          <div
            style={{
              transform:  `translate(-50%, -50%) translate(${labelX}px,${labelY}px)`,
              position:   'absolute',
            }}
            className="text-[10px] font-mono text-[#7D8590] bg-[#161B22] border border-[#30363D] px-1.5 py-0.5 rounded pointer-events-none"
          >
            {String(d.fkColumn)} → {target}
          </div>
        </EdgeLabelRenderer>
      )}
    </>
  )
}
