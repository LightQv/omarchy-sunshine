const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8");
const Model = {};
vm.createContext(Model);
vm.runInContext(source, Model, { filename: "Model.js" });

function status(active, unit = "disabled", load = "loaded") {
  return `LoadState=${load}\nActiveState=${active}\nSubState=dead\nUnitFileState=${unit}\n`;
}

test("maps systemd runtime and auto-start states", () => {
  assert.equal(Model.parseSystemctl(status("inactive")).runtimeState, "off");
  assert.equal(Model.parseSystemctl(status("activating")).runtimeState, "starting");
  assert.equal(Model.parseSystemctl(status("active", "enabled")).runtimeState, "on");
  assert.equal(Model.parseSystemctl(status("deactivating")).runtimeState, "stopping");
  assert.equal(Model.parseSystemctl(status("failed")).runtimeState, "failed");
  assert.equal(Model.parseSystemctl(status("active", "enabled-runtime")).autoStartKnown, false);
});

test("reports a missing unit as not installed", () => {
  const result = Model.parseSystemctl(status("inactive", "", "not-found"));
  assert.equal(result.valid, false);
  assert.equal(result.missing, true);
  assert.equal(result.installed, false);
  assert.equal(result.error, "Sunshine is not installed.");
});

test("rejects incomplete, duplicate, unknown, and oversized status", () => {
  assert.equal(Model.parseSystemctl("ActiveState=active\n").valid, false);
  assert.equal(Model.parseSystemctl(status("active") + "ActiveState=inactive\n").valid, false);
  assert.equal(Model.parseSystemctl(status("reloading")).valid, false);
  assert.equal(Model.parseSystemctl("x".repeat(16385)).valid, false);
});

test("keeps unknown unit-file states explicit", () => {
  const result = Model.parseSystemctl(status("active", "masked"));
  assert.equal(result.installed, true);
  assert.equal(result.autoStartKnown, false);
  assert.match(result.error, /auto-start/);
});

test("parses Sunshine ports and uses the final assignment", () => {
  assert.equal(Model.parseBasePort(""), 47989);
  assert.equal(Model.parseBasePort("port = 48000\n"), 48000);
  assert.equal(Model.parseBasePort("# port = 1\nport=48000 ; local\nport = 49000"), 49000);
  assert.equal(Model.parseBasePort("port = invalid"), 47989);
  assert.equal(Model.parseBasePort("port = 65515"), 47989);
  assert.equal(Model.parseBasePort("port = 1028"), 47989);
  assert.equal(Model.parseBasePort("x".repeat(1048577)), 47989);
});

test("formats bounded factual tooltips", () => {
  assert.equal(Model.statusLabel("starting"), "Starting");
  assert.equal(Model.tooltip("on", true, true, ""),
    "Sunshine\nStatus: On\nAuto-start: On");
  assert.ok(Model.tooltip("failed", true, false, "x".repeat(500)).length < 250);
});
