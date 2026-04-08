import type { Diff, Migration, MigrationDetail } from '../types/migration'

function getApiBase(): string {
  const root = document.getElementById('schema-trail-root')
  return root?.dataset.apiBase ?? '/migflow/api'
}

async function get<T>(path: string): Promise<T> {
  const response = await fetch(`${getApiBase()}${path}`, {
    headers: { Accept: 'application/json' },
  })

  if (!response.ok) {
    throw new Error(`API error ${response.status}: ${response.statusText}`)
  }

  return response.json() as Promise<T>
}

export const client = {
  getMigrations(): Promise<Migration[]> {
    return get<{ migrations: Migration[] }>('/migrations').then((r) => r.migrations)
  },

  getMigrationDetail(version: string): Promise<MigrationDetail> {
    return get<{ migration: MigrationDetail }>(`/migrations/${version}`).then((r) => r.migration)
  },

  getDiff(from: string, to: string): Promise<Diff> {
    return get<{ diff: Diff }>(`/diff?from=${from}&to=${to}`).then((r) => r.diff)
  },
}
