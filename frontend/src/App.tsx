import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useSchemaStore } from './store/useSchemaStore'
import { Timeline } from './components/Timeline'
import { SchemaCanvas } from './components/SchemaCanvas'
import { SchemaDiffView } from './components/SchemaDiffView'
import { DetailPanel } from './components/DetailPanel'
import { CompareBar } from './components/CompareBar'
import { ResizablePanel } from './components/ResizablePanel'

const queryClient = new QueryClient({
  defaultOptions: { queries: { staleTime: 30_000, retry: 1 } },
})

function Layout() {
  const {
    selectedVersion,
    viewMode,
    isRightPanelCollapsed,
    toggleRightPanelCollapsed,
  } = useSchemaStore()

  return (
    <div className="flex flex-col h-screen bg-[#0D1117] text-[#E6EDF3] overflow-hidden">
      <header className="flex items-center gap-3 px-5 h-12 border-b border-[#30363D] shrink-0">
        <span className="text-[#58A6FF] font-mono font-semibold tracking-wider text-sm">Migflow</span>
        <span className="text-[#7D8590] text-xs font-mono">migration intelligence for Rails</span>
      </header>

      <div className="flex flex-1 min-h-0">
        <ResizablePanel
          initialWidth={280}
          minWidth={200}
          maxWidth={600}
          side="left"
          className="border-r border-[#30363D] overflow-hidden"
        >
          <div className="h-full overflow-y-auto">
            <Timeline />
          </div>
        </ResizablePanel>

        <main className="flex-1 min-w-0 relative flex flex-col min-h-0">
          <CompareBar />
          <div className="flex-1 min-h-0 relative">
            <div
              className={viewMode === 'flow' ? 'absolute inset-0' : 'absolute inset-0 hidden'}
              aria-hidden={viewMode !== 'flow'}
            >
              <SchemaCanvas />
            </div>
            <div
              className={viewMode === 'schema' ? 'absolute inset-0' : 'absolute inset-0 hidden'}
              aria-hidden={viewMode !== 'schema'}
            >
              <SchemaDiffView />
            </div>
          </div>
        </main>

        {selectedVersion && (
          <ResizablePanel
            initialWidth={320}
            minWidth={200}
            maxWidth={600}
            side="right"
            collapsed={isRightPanelCollapsed}
            onToggleCollapse={toggleRightPanelCollapsed}
            className="border-l border-[#30363D] overflow-hidden"
          >
            <div className="h-full flex flex-col min-h-0">
              <div className="flex items-center justify-end px-2 py-1.5 border-b border-[#30363D] shrink-0 bg-[#0D1117]">
                <button
                  type="button"
                  onClick={toggleRightPanelCollapsed}
                  aria-label="Collapse detail panel"
                  className="p-1 rounded-md text-[#7D8590] hover:text-[#E6EDF3] hover:bg-[#21262D] transition-colors"
                >
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
                    <path d="M9 18l6-6-6-6" />
                  </svg>
                </button>
              </div>
              <div className="flex-1 min-h-0 overflow-hidden">
                <DetailPanel />
              </div>
            </div>
          </ResizablePanel>
        )}
      </div>

    </div>
  )
}

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <Layout />
    </QueryClientProvider>
  )
}
