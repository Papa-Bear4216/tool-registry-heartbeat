import assert from "node:assert/strict";
import test from "node:test";
import { handleHeartbeatDelegate } from "./delegate.mjs";

test("inventory lists the scheduled task scripts", () => {
  const outcome = handleHeartbeatDelegate({
    v: 1,
    id: "0123456789abcdef",
    from: "pieces-android-companion-seamless",
    to: "tool-registry-heartbeat",
    capability: "inventory",
    action: "inventory",
    payload: {},
  });
  assert.equal(outcome.status, 200);
  assert.ok(outcome.body.result.scripts.includes("heartbeat-wrapper.ps1"));
  assert.ok(outcome.body.result.scripts.includes("feature-gap-wrapper.ps1"));
});
