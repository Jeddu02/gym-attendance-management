import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { toPostgresBytea } from "./postgres-bytea.ts";

Deno.test("encodes binary bytes as PostgreSQL hexadecimal bytea", () => {
  const result = toPostgresBytea(
    new Uint8Array([0, 1, 15, 16, 127, 128, 255]),
  );

  assertEquals(result, "\\x00010f107f80ff");
});

Deno.test("preserves all 32 bytes of a mobile lookup hash", () => {
  const bytes = new Uint8Array(32).fill(0x11);

  assertEquals(toPostgresBytea(bytes), "\\x" + "11".repeat(32));
});

Deno.test("preserves encrypted mobile data bytes", () => {
  const bytes = new Uint8Array(29).fill(0x22);

  assertEquals(toPostgresBytea(bytes), "\\x" + "22".repeat(29));
});

Deno.test("rejects empty binary values", () => {
  assertThrows(() => toPostgresBytea(new Uint8Array()));
});
