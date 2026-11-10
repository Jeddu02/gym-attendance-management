/** Preserve database decimal cents, including aggregates beyond JS safe integers. */
export function formatPhp(value: string | number): string {
  if (typeof value === 'number' && (!Number.isFinite(value) || Math.abs(value) > Number.MAX_SAFE_INTEGER / 100)) throw Error('Unsafe money value');
  const text = String(value);
  if (text.length > 100 || !/^-?[0-9]+(?:\.[0-9]{1,2})?$/u.test(text)) throw Error('Invalid money value');
  const negative = text.startsWith('-');
  const [whole, fraction = ''] = text.replace(/^-/, '').split('.');
  return `${negative ? '-' : ''}₱${BigInt(whole).toLocaleString('en-PH')}.${fraction.padEnd(2, '0')}`;
}
