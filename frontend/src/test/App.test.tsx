import { render, screen } from '@testing-library/react'
import App from '../App'

vi.mock('../components/SchemaCanvas', () => ({
  SchemaCanvas: () => <div data-testid="schema-canvas" />,
}))

vi.mock('../components/Timeline', () => ({
  Timeline: () => <div data-testid="timeline" />,
}))

vi.mock('../api/client', () => ({
  client: {
    getMigrations: vi.fn().mockResolvedValue([]),
    getMigrationDetail: vi.fn().mockResolvedValue(null),
    getDiff: vi.fn().mockResolvedValue(null),
  },
}))

describe('App', () => {
  it('renders the header with Migflow branding', () => {
    render(<App />)
    expect(screen.getByText('Migflow')).toBeInTheDocument()
    expect(screen.getByText('migration history & audit')).toBeInTheDocument()
  })

  it('does not render the detail panel when no version is selected', () => {
    render(<App />)
    expect(screen.queryByLabelText('Collapse detail panel')).not.toBeInTheDocument()
  })
})
