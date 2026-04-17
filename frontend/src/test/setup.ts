import '@testing-library/jest-dom/vitest'
import { afterEach } from 'vitest'
import { useSchemaStore } from '../store/useSchemaStore'

afterEach(() => {
  useSchemaStore.setState({
    selectedVersion: null,
    compareTo: null,
    highlightedEdgeId: null,
    selectedTableId: null,
    selectedEdgeId: null,
    collapsedTables: new Set(),
    viewMode: 'flow',
    isRightPanelCollapsed: false,
  })
})
