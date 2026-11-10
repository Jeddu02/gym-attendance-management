/** RFC4180 output. Prefix untrusted spreadsheet formula strings before quoting. */
export function csvDocument(headers: string[], rows: (string | number | null)[][]): string {
  function cell(value: string | number | null): string {
    if (typeof value === 'number' && !Number.isFinite(value)) throw new Error('Invalid export number');
    let text = value === null ? '' : String(value);
    // eslint-disable-next-line no-control-regex -- Spreadsheet formula prefixes may follow control characters.
    if (typeof value === 'string' && /^[\s\u0000-\u0020]*[=+\-@]/u.test(text)) text = "'" + text;
    return '"' + text.replaceAll('"', '""') + '"';
  }
  if (rows.some((row) => row.length !== headers.length)) throw new Error('Invalid export columns');
  return '\uFEFF' + [headers, ...rows].map(row => row.map(cell).join(',')).join('\r\n') + '\r\n';
}

export function downloadCsv(filename: string, headers: string[], rows: (string | number | null)[][]): void {
  const url = URL.createObjectURL(new Blob([csvDocument(headers, rows)], { type: 'text/csv;charset=utf-8' }));
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
}
