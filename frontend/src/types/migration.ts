export type RiskLevel = 'safe' | 'low' | 'medium' | 'high'

export interface RiskFactor {
  rule: string
  message: string
  weight: number
}

export interface Migration {
  version: string
  name: string
  filename: string
  summary: string
  risk_score: number
  risk_level: RiskLevel
}

export interface Column {
  name: string
  type: string
  null: boolean
  default: string | null
  limit?: number
}

export interface Index {
  name: string
  columns: string[]
  unique: boolean
}

export interface Table {
  columns: Column[]
  indexes: Index[]
}

export interface Schema {
  tables: Record<string, Table>
}

export interface MigrationDiff {
  added_tables: string[]
  removed_tables: string[]
  modified_tables: Record<string, { added_columns: string[]; removed_columns: string[] }>
}

export interface MigrationDetail extends Migration {
  raw_content: string | null
  schema_after: Schema
  diff: MigrationDiff
  schema_patch: string
  schema_patch_full: string
  warnings: Warning[]
  risk_factors: RiskFactor[]
}

export interface Warning {
  rule: string
  severity: 'error' | 'warning' | 'info'
  table: string
  column: string | null
  message: string
}

export interface ColumnWithDiff extends Column {
  diffStatus?: 'added' | 'removed'
}

export interface IndexWithDiff extends Index {
  diffStatus?: 'added' | 'removed'
}

export interface DiffInfo {
  addedTables: Set<string>
  removedTables: Set<string>
  addedColumns: Map<string, string[]>
  removedColumns: Map<string, string[]>
  addedIndexColumns: Map<string, string[]>
  removedIndexColumns: Map<string, string[]>
}

export interface DiffChange {
  type: 'added_table' | 'removed_table' | 'added_column' | 'removed_column' | 'added_index' | 'removed_index'
  table: string
  detail: string
}

export interface Diff {
  from_version: string
  to_version: string
  changes: DiffChange[]
  schema_patch: string
  schema_patch_full: string
}
