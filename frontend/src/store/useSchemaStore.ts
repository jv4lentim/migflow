import { create } from 'zustand'

interface SchemaStore {
  selectedVersion:    string | null
  compareFrom:        string | null
  compareTo:          string | null
  isCompareMode:      boolean
  highlightedEdgeId:  string | null
  selectedTableId:    string | null
  selectedEdgeId:     string | null

  setSelectedVersion:   (version: string) => void
  setCompareFrom:       (version: string) => void
  setCompareTo:         (version: string) => void
  toggleCompareMode:    () => void
  setHighlightedEdgeId: (id: string | null) => void
  setSelectedTableId:   (id: string | null) => void
  setSelectedEdgeId:    (id: string | null) => void
}

export const useSchemaStore = create<SchemaStore>((set) => ({
  selectedVersion:    null,
  compareFrom:        null,
  compareTo:          null,
  isCompareMode:      false,
  highlightedEdgeId:  null,
  selectedTableId:    null,
  selectedEdgeId:     null,

  setSelectedVersion:   (version) => set({ selectedVersion: version }),
  setCompareFrom:       (version) => set({ compareFrom: version }),
  setCompareTo:         (version) => set({ compareTo: version }),
  toggleCompareMode:    () => set((state) => ({ isCompareMode: !state.isCompareMode })),
  setHighlightedEdgeId: (id)      => set({ highlightedEdgeId: id }),
  setSelectedTableId:   (id)      => set({ selectedTableId: id }),
  setSelectedEdgeId:    (id)      => set({ selectedEdgeId: id }),
}))
