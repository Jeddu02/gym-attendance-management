import { assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import { capabilityBytes, capabilityDigest, parseRecoveryInput, recoveryResponse } from "./walkin-recovery.ts";
const key = "A".repeat(43);
Deno.test("recovery capability requires canonical 256-bit encoding", () => {
  assertEquals(capabilityBytes(key)?.length,32);
  for (const value of [null,"",key+"=",key.slice(1),"A".repeat(42)+"B"]) assertEquals(capabilityBytes(value),null);
});
Deno.test("recovery parser rejects identity, fee, key and action overrides", () => {
  assertEquals(parseRecoveryInput({action:"lookup",capability:key}),{action:"lookup",capability:key});
  for(const paymentMethod of ["cash","gcash","bank_transfer"]) assertNotEquals(parseRecoveryInput({action:"create",capability:key,paymentMethod}),null);
  for(const value of [null,[],{}, {action:"create",capability:key}, {action:"lookup",capability:key,requestId:"private"}, {action:"create",capability:key,paymentMethod:"cash",feePhp:"1"}]) assertEquals(parseRecoveryInput(value),null);
});
Deno.test("recovery digest is domain-separated and never raw capability", async () => {
  const value=await capabilityDigest(key);
  assertEquals(/^\\x[0-9a-f]{64}$/.test(value),true);
  assertEquals(value,await capabilityDigest(key));
  assertNotEquals(value,"\\x"+"0".repeat(64));
});
Deno.test("recovery response rejects malformed success and strips private fields", () => {
  const input={action:"create" as const,capability:key,paymentMethod:"cash" as const};
  for(const value of [null,{},[],{classification:"PROVISIONAL_CREATED",request:{}}]) assertEquals(recoveryResponse(value,input),null);
  for(const [classification,status]of [["OPERATION_CONFLICT",409],["RECOVERY_CLOSED",410],["NO_RECOVERABLE_OUTCOME",404]] as const)
    assertEquals(recoveryResponse({classification,privateData:"secret"},input),{status,body:{error:classification}});
  const request={id:"91000000-0000-4000-8000-000000000001",feePhp:"125.00",currency:"PHP",paymentMethod:"cash",createdAt:"2026-11-19T00:00:00Z",expiresAt:"2026-11-19T00:15:00Z"};
  assertEquals(recoveryResponse({classification:"PROVISIONAL_CREATED",request:{...request,receiptId:"private"}},input),{status:201,body:{success:true,classification:"PROVISIONAL_CREATED",request}});
});
