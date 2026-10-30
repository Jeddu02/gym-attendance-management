export function toPostgresBytea(bytes: Uint8Array): string {
  if (!(bytes instanceof Uint8Array) || bytes.length === 0) {
    throw new Error("Invalid binary value");
  }

  const hex = Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");

  return `\\x${hex}`;
}
