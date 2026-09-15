export const MIGRATION_SEQUENCE_DIGITS = 4;

export function migrationSequence(index) {
  return String(index).padStart(MIGRATION_SEQUENCE_DIGITS, '0');
}

export function migrationIndex(fileName) {
  return Number(fileName.slice(0, MIGRATION_SEQUENCE_DIGITS));
}
