"use strict";

var DEFAULT_BASE_PORT = 47989;
var MAX_CONFIG_LENGTH = 1048576;
var MAX_STATUS_LENGTH = 16384;

function hasOwn(value, key) {
  return Object.prototype.hasOwnProperty.call(value, key);
}

function invalidStatus(message) {
  return {
    valid: false,
    missing: false,
    installed: false,
    runtimeState: "unavailable",
    autoStartKnown: false,
    autoStartEnabled: false,
    error: message
  };
}

function parseSystemctl(raw) {
  var text = String(raw || "");
  if (text.length === 0) return invalidStatus("Sunshine returned no service status.");
  if (text.length > MAX_STATUS_LENGTH) return invalidStatus("Sunshine service status was too large.");

  var values = Object.create(null);
  var allowed = { LoadState: true, ActiveState: true, SubState: true, UnitFileState: true };
  var lines = text.split(/\r?\n/);
  for (var i = 0; i < lines.length; i++) {
    if (lines[i] === "") continue;
    var separator = lines[i].indexOf("=");
    if (separator < 1) return invalidStatus("Sunshine returned malformed service status.");
    var key = lines[i].slice(0, separator);
    if (!hasOwn(allowed, key) || hasOwn(values, key))
      return invalidStatus("Sunshine returned unsupported service status.");
    values[key] = lines[i].slice(separator + 1);
  }

  if (!hasOwn(values, "LoadState") || !hasOwn(values, "ActiveState")
      || !hasOwn(values, "SubState") || !hasOwn(values, "UnitFileState"))
    return invalidStatus("Sunshine service status was incomplete.");

  if (values.LoadState === "not-found") {
    var missing = invalidStatus("Sunshine is not installed.");
    missing.missing = true;
    return missing;
  }
  if (values.LoadState !== "loaded") return invalidStatus("Sunshine's service is unavailable.");

  var stateMap = {
    inactive: "off",
    activating: "starting",
    active: "on",
    deactivating: "stopping",
    failed: "failed"
  };
  if (!hasOwn(stateMap, values.ActiveState))
    return invalidStatus("Sunshine returned an unknown runtime state.");

  var unitState = values.UnitFileState;
  var autoStartKnown = unitState === "enabled" || unitState === "disabled";
  return {
    valid: true,
    missing: false,
    installed: true,
    runtimeState: stateMap[values.ActiveState],
    autoStartKnown: autoStartKnown,
    autoStartEnabled: unitState === "enabled",
    error: autoStartKnown ? "" : "Sunshine returned an unknown auto-start state."
  };
}

function parseBasePort(raw) {
  var text = String(raw || "");
  if (text.length > MAX_CONFIG_LENGTH) return DEFAULT_BASE_PORT;
  var selected = null;
  var lines = text.split(/\r?\n/);
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].replace(/\s*[#;].*$/, "").trim();
    if (line === "") continue;
    var match = line.match(/^port\s*=\s*(.*?)\s*$/);
    if (match) selected = match[1];
  }
  if (selected === null || !/^[0-9]+$/.test(selected)) return DEFAULT_BASE_PORT;
  var port = Number(selected);
  return port >= 1029 && port <= 65514 ? port : DEFAULT_BASE_PORT;
}

function statusLabel(state) {
  var labels = {
    unavailable: "Unavailable",
    off: "Off",
    starting: "Starting",
    on: "On",
    stopping: "Stopping",
    failed: "Failed"
  };
  return hasOwn(labels, state) ? labels[state] : "Unavailable";
}

function tooltip(state, autoStartKnown, autoStartEnabled, error) {
  var lines = ["Sunshine", "Status: " + statusLabel(state)];
  lines.push("Auto-start: " + (autoStartKnown ? (autoStartEnabled ? "On" : "Off") : "Unknown"));
  if (error) lines.push(String(error).slice(0, 160));
  return lines.join("\n");
}
