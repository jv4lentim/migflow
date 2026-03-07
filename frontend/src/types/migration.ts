export interface Migration {
  version: string
  name: string
  filename: string
  summary: string
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
  raw_content: string
  schema_after: Schema
  diff: MigrationDiff
  warnings: Warning[]
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
}
