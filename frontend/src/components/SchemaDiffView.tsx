import { useMemo, useState } from 'react'
import { Diff, Hunk, parseDiff } from 'react-diff-view'
import 'react-diff-view/style/index.css'
import { useSchemaComparisonData } from '../hooks/useSchemaComparisonData'

function EmptyState({ message }: { message: string }) {
  return (
    <div className="flex flex-col items-center justify-center h-full text-[#7D8590] px-6 text-center">
      <p className="text-4xl mb-4">⬡</p>
      <p className="text-sm max-w-sm font-mono">{message}</p>
    </div>
  )
}

export function SchemaDiffView() {
  const {
    selectedVersion,
    comparePairValid,
    loadingBase,
    loadingTarget,
    loadingBasePrevious,
    activeDetail,
    compareDiff,
    loadingCompareDiff,
  } = useSchemaComparisonData()
  const [showUnchangedTables, setShowUnchangedTables] = useState(false)

  const patchText = useMemo(() => {
    if (comparePairValid) {
      if (!compareDiff) return ''
      return showUnchangedTables ? compareDiff.schema_patch_full : compareDiff.schema_patch
    }
    if (!activeDetail) return ''
    return showUnchangedTables ? activeDetail.schema_patch_full : activeDetail.schema_patch
  }, [comparePairValid, compareDiff, activeDetail, showUnchangedTables])

  const hasFullPatch = useMemo(() => {
    if (comparePairValid) return !!compareDiff?.schema_patch_full
    return !!activeDetail?.schema_patch_full
  }, [comparePairValid, compareDiff, activeDetail])
  const files = useMemo(() => {
    if (!patchText.includes('@@')) return []
    try {
      return parseDiff(patchText).filter((file) => Array.isArray(file.hunks) && file.hunks.length > 0)
    } catch {
      return []
    }
  }, [patchText])

  if (!selectedVersion) {
    return <EmptyState message="Select a migration from the timeline" />
  }

  const loadingBaseOnlyPrevious = !comparePairValid && !!selectedVersion && loadingBasePrevious
  if (loadingBase || loadingBaseOnlyPrevious || (comparePairValid && (loadingTarget || loadingCompareDiff))) {
    return (
      <div className="flex items-center justify-center h-full text-[#7D8590] text-sm font-mono">
        Loading schemas…
      </div>
    )
  }

  if (!activeDetail?.schema_after.tables) {
    return (
      <EmptyState message="Schema not available for selected migration." />
    )
  }

  return (
    <div className="h-full bg-[#0D1117] p-4">
      <div className="h-full rounded-md border border-[#30363D] bg-[#161B22] overflow-hidden shadow-lg">
        <div className="flex items-center justify-between gap-3 px-4 py-2 border-b border-[#30363D] bg-[#0D1117]">
          <div className="flex items-center gap-3 min-w-0">
            <p className="text-xs font-mono text-[#E6EDF3] truncate">schema.rb</p>
            {hasFullPatch && (
              <button
                type="button"
                onClick={() => setShowUnchangedTables((current) => !current)}
                className="text-[10px] font-mono uppercase tracking-wider px-2 py-1 rounded border border-[#30363D] text-[#7D8590] hover:text-[#E6EDF3] hover:border-[#7D8590] transition-colors"
              >
                {showUnchangedTables ? 'Collapse unchanged' : 'Expand hidden lines'}
              </button>
            )}
          </div>
          <span className="text-[10px] font-mono text-[#7D8590] uppercase tracking-wider">{files.length} file</span>
        </div>
        <div className="h-[calc(100%-41px)] min-h-0 overflow-auto p-3 text-xs">
          {files.length === 0
            ? (
                <p className="px-2 py-2 text-[#7D8590]">No schema lines to display.</p>
              )
            : (
                files.map((file) => (
                  <div key={`${file.oldRevision}-${file.newRevision}-${file.oldPath}`}>
                    {file.hunks.map((hunk, idx) => (
                      <div key={`hunk-${idx}`} className={idx > 0 ? 'mt-3' : ''}>
                        <Diff
                          viewType="split"
                          diffType={file.type}
                          hunks={[hunk]}
                          optimizeSelection
                          className="migflow-schema-diff !bg-[#161B22] !text-[#E6EDF3]"
                        >
                          {(renderHunks) => renderHunks.map((renderHunk, renderIdx) => (
                            <Hunk key={`render-hunk-${renderIdx}`} hunk={renderHunk} />
                          ))}
                        </Diff>
                      </div>
                    ))}
                  </div>
                ))
              )}
          </div>
      </div>
    </div>
  )
}
