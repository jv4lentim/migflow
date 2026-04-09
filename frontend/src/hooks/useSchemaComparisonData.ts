import { useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import { client } from '../api/client'
import { useSchemaStore } from '../store/useSchemaStore'
import { diffInfoFromApi, emptyDiffInfo } from '../utils/parseMigrationChanges'
import { schemasToDiffInfo } from '../utils/schemaDiffToDiffInfo'
import { mergeScopedWarnings, countWarningsByTable } from '../utils/schemaWarnings'

export function useSchemaComparisonData() {
  const { selectedVersion, compareTo } = useSchemaStore()

  const comparePairValid =
    !!selectedVersion
    && !!compareTo
    && compareTo !== selectedVersion

  const { data: migrations } = useQuery({
    queryKey: ['migrations'],
    queryFn: client.getMigrations,
  })

  const orderedVersions = useMemo(
    () => [...(migrations ?? [])].map((m) => m.version).sort(),
    [migrations],
  )

  const basePreviousVersion = useMemo(() => {
    if (!selectedVersion) return null
    const idx = orderedVersions.indexOf(selectedVersion)
    if (idx <= 0) return null
    return orderedVersions[idx - 1] ?? null
  }, [selectedVersion, orderedVersions])

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

  const { data: detailBasePrevious, isPending: loadingBasePrevious } = useQuery({
    queryKey: ['migration', basePreviousVersion],
    queryFn: () => client.getMigrationDetail(basePreviousVersion!),
    enabled: !!selectedVersion && !!basePreviousVersion,
  })

  const { data: compareDiff, isPending: loadingCompareDiff } = useQuery({
    queryKey: ['diff', selectedVersion, compareTo],
    queryFn: () => client.getDiff(selectedVersion!, compareTo!),
    enabled: comparePairValid,
  })

  const scopedWarnings = useMemo(
    () => mergeScopedWarnings(detailBase?.warnings, detailTarget?.warnings, comparePairValid),
    [detailBase?.warnings, detailTarget?.warnings, comparePairValid],
  )

  const activeDetail = comparePairValid ? detailTarget : detailBase
  const diff = detailBase?.diff
  const diffInfo = useMemo(() => {
    if (comparePairValid && detailTarget) {
      const fromTables = basePreviousVersion
        ? (detailBasePrevious?.schema_after.tables ?? {})
        : {}
      return schemasToDiffInfo(fromTables, detailTarget.schema_after.tables)
    }
    if (!diff) return emptyDiffInfo()
    return diffInfoFromApi(diff)
  }, [comparePairValid, detailTarget, basePreviousVersion, detailBasePrevious, diff])

  const warningCountByTable = useMemo(
    () => countWarningsByTable(scopedWarnings),
    [scopedWarnings],
  )

  return {
    selectedVersion,
    compareTo,
    comparePairValid,
    detailBase,
    detailTarget,
    detailBasePrevious,
    loadingBase,
    loadingTarget,
    loadingBasePrevious,
    loadingCompareDiff,
    activeDetail,
    diffInfo,
    compareDiff,
    warningCountByTable,
  }
}
