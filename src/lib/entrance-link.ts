/** The printed QR contains only a public entrance URL. */
export function entranceDestination(baseUrl: string): string {
  const url = new URL(baseUrl.trim());
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash
    || !['/', '/entrance', '/entrance/'].includes(url.pathname)) {
    throw new Error('Enter the HTTPS site origin or its public /entrance URL.');
  }
  return `${url.origin}/entrance`;
}
