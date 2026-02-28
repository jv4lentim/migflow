import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useSchemaStore } from './store/useSchemaStore'
import { Timeline } from './components/Timeline'
import { SchemaCanvas } from './components/SchemaCanvas'
import { DetailPanel } from './components/DetailPanel'
import { CompareBar } from './components/CompareBar'

const queryClient = new QueryClient({
  defaultOptions: { queries: { staleTime: 30_000, retry: 1 } },
})

function Layout() {
  const { selectedVersion, isCompareMode } = useSchemaStore()

  return (
    <div className="flex flex-col h-screen bg-[#0D1117] text-[#E6EDF3] overflow-hidden">
      <header className="flex items-center gap-3 px-5 h-12 border-b border-[#30363D] shrink-0">
        <span className="text-[#58A6FF] font-mono font-semibold tracking-wider text-sm">migrail</span>
        <span className="text-[#7D8590] text-xs font-mono">migration history & audit</span>
      </header>

      <div className="flex flex-1 min-h-0">
        <aside className="w-[280px] shrink-0 border-r border-[#30363D] overflow-y-auto">
          <Timeline />
        </aside>

        <main className="flex-1 min-w-0 relative">
          <SchemaCanvas />
        </main>

        {selectedVersion && (
          <aside className="w-[320px] shrink-0 border-l border-[#30363D] overflow-y-auto">
            <DetailPanel />
          </aside>
        )}
      </div>

      {isCompareMode && (
        <footer className="h-[60px] shrink-0 border-t border-[#30363D]">
          <CompareBar />
        </footer>
      )}
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
