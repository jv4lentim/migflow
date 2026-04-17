import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { CompareBar } from '../components/CompareBar'
import { useSchemaStore } from '../store/useSchemaStore'

vi.mock('../api/client', () => ({
  client: {
    getMigrations: vi.fn().mockResolvedValue([]),
    getDiff: vi.fn().mockResolvedValue(null),
  },
}))

function createWrapper() {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={qc}>{children}</QueryClientProvider>
  )
}

describe('CompareBar', () => {
  it('renders Flow and Schema view mode tabs', () => {
    render(<CompareBar />, { wrapper: createWrapper() })
    expect(screen.getByRole('tab', { name: 'Flow' })).toBeInTheDocument()
    expect(screen.getByRole('tab', { name: 'Schema' })).toBeInTheDocument()
  })

  it('disables the compare target select when no version is selected', () => {
    render(<CompareBar />, { wrapper: createWrapper() })
    expect(screen.getByRole('combobox', { name: /compare target/i })).toBeDisabled()
  })

  it('shows the placeholder text when no base migration is selected', () => {
    render(<CompareBar />, { wrapper: createWrapper() })
    expect(screen.getByText('Select a migration in the timeline')).toBeInTheDocument()
  })

  it('switches view mode to schema when the Schema tab is clicked', async () => {
    const user = userEvent.setup()
    render(<CompareBar />, { wrapper: createWrapper() })
    await user.click(screen.getByRole('tab', { name: 'Schema' }))
    expect(useSchemaStore.getState().viewMode).toBe('schema')
  })

  it('Flow tab is selected by default', () => {
    render(<CompareBar />, { wrapper: createWrapper() })
    expect(screen.getByRole('tab', { name: 'Flow' })).toHaveAttribute('aria-selected', 'true')
    expect(screen.getByRole('tab', { name: 'Schema' })).toHaveAttribute('aria-selected', 'false')
  })
})
