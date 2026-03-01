export const HEADER_HEIGHT   = 40
export const COLUMN_HEIGHT   = 28
export const NODE_BORDER     = 1
export const NODE_PADDING_TOP = 0
export const NODE_WIDTH      = 220

export function nodeHeight(columnCount: number): number {
  return HEADER_HEIGHT + columnCount * COLUMN_HEIGHT
}
