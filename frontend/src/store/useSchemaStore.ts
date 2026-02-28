import { create } from 'zustand'

interface SchemaStore {
  selectedVersion: string | null
  compareFrom: string | null
  compareTo: string | null
  isCompareMode: boolean
  setSelectedVersion: (version: string) => void
  setCompareFrom: (version: string) => void
  setCompareTo: (version: string) => void
  toggleCompareMode: () => void
}

export const useSchemaStore = create<SchemaStore>((set) => ({
  selectedVersion: null,
  compareFrom: null,
  compareTo: null,
  isCompareMode: false,

  setSelectedVersion: (version) => set({ selectedVersion: version }),
  setCompareFrom: (version) => set({ compareFrom: version }),
  setCompareTo: (version) => set({ compareTo: version }),
  toggleCompareMode: () => set((state) => ({ isCompareMode: !state.isCompareMode })),
}))
