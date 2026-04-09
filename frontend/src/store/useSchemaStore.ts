import { create } from 'zustand'

export type ViewMode = 'flow' | 'schema'

interface SchemaStore {
  selectedVersion:    string | null
  /** Optional compare target; null = none (canvas shows base only). */
  compareTo:          string | null
  highlightedEdgeId:  string | null
  selectedTableId:    string | null
  selectedEdgeId:     string | null
  collapsedTables:    Set<string>
  viewMode:           ViewMode
  isRightPanelCollapsed: boolean

  setSelectedVersion:   (version: string) => void
  selectMigration:      (version: string) => void
  setCompareTo:         (version: string | null) => void
  setHighlightedEdgeId: (id: string | null) => void
  setSelectedTableId:   (id: string | null) => void
  setSelectedEdgeId:    (id: string | null) => void
  toggleTableCollapsed: (tableId: string) => void
  setViewMode:          (mode: ViewMode) => void
  toggleRightPanelCollapsed: () => void
  setRightPanelCollapsed: (collapsed: boolean) => void
}

export const useSchemaStore = create<SchemaStore>((set) => ({
  selectedVersion:    null,
  compareTo:          null,
  highlightedEdgeId:  null,
  selectedTableId:    null,
  selectedEdgeId:     null,
  collapsedTables:    new Set<string>(),
  viewMode:           'flow',
  isRightPanelCollapsed: false,

  setSelectedVersion:   (version) => set({ selectedVersion: version }),
  selectMigration:      (version) => set((s) => ({
    selectedVersion: version,
    selectedTableId:  null,
    selectedEdgeId:  null,
    compareTo:         s.compareTo,
  })),
  setCompareTo:         (version) => set({ compareTo: version || null }),
  setHighlightedEdgeId: (id)      => set({ highlightedEdgeId: id }),
  setSelectedTableId:   (id)      => set({ selectedTableId: id }),
  setSelectedEdgeId:    (id)      => set({ selectedEdgeId: id }),
  toggleTableCollapsed: (tableId) => set((state) => {
    const next = new Set(state.collapsedTables)
    if (next.has(tableId)) next.delete(tableId)
    else next.add(tableId)
    return { collapsedTables: next }
  }),
  setViewMode:          (mode) => set({ viewMode: mode }),
  toggleRightPanelCollapsed: () => set((s) => ({ isRightPanelCollapsed: !s.isRightPanelCollapsed })),
  setRightPanelCollapsed: (collapsed) => set({ isRightPanelCollapsed: collapsed }),
}))
