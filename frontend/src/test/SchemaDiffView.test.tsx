import { render, screen } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { SchemaDiffView } from '../components/SchemaDiffView'
import { useSchemaStore } from '../store/useSchemaStore'

vi.mock('../api/client', () => ({
  client: {
    getMigrations: vi.fn().mockResolvedValue([]),
    getMigrationDetail: vi.fn().mockResolvedValue(null),
    getDiff: vi.fn().mockResolvedValue(null),
  },
}))

function createWrapper() {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={qc}>{children}</QueryClientProvider>
  )
}

describe('SchemaDiffView', () => {
  it('shows an empty state when no migration is selected', () => {
    render(<SchemaDiffView />, { wrapper: createWrapper() })
    expect(screen.getByText('Select a migration from the timeline')).toBeInTheDocument()
  })

  it('does not show the empty-state message once a version is selected', () => {
    useSchemaStore.setState({ selectedVersion: '20240101000000' })
    render(<SchemaDiffView />, { wrapper: createWrapper() })
    expect(screen.queryByText('Select a migration from the timeline')).not.toBeInTheDocument()
  })

  it('shows a loading indicator while schema data is fetching', () => {
    useSchemaStore.setState({ selectedVersion: '20240101000000' })
    render(<SchemaDiffView />, { wrapper: createWrapper() })
    expect(screen.getByText('Loading schemas…')).toBeInTheDocument()
  })
})
