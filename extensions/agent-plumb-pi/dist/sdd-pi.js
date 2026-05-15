// sdd-pi.js — pi.dev extension entry for sdd-pi-adapter.
//
// Wires the bash scripts in ../scripts/ to pi.dev's lifecycle events so
// SDD's discipline (state injection, HRN-01 install, instant /sdd-status)
// fires automatically the way the spec promised. Without this file,
// pi.dev only surfaces our prompt templates — the load-bearing
// automatic state injection (AC3), HRN-01 copy on first run (AC4), and
// zero-LLM /sdd-status (AC7) all silently no-op.
//
// Hand-written CommonJS — no TS toolchain, no build step. Modeled on
// pi-gsd-hooks.ts (badlogic/pi-mono ecosystem) but stripped down for
// SDD's simpler shape. Each handler shells out to an existing bash
// script under ../scripts/ and either injects the output (context),
// runs it for side-effects (session_start), or renders the result
// (registerCommand).
//
// Non-blocking guarantee: every handler swallows errors silently so
// hook failures never block tool execution or session startup.

"use strict";

const { execFileSync } = require("node:child_process");
const { existsSync } = require("node:fs");
const { dirname, join, resolve } = require("node:path");

// Resolve the extension's own directory so we can find ../scripts/
// regardless of where pi installed the package or where the user runs
// pi from. __filename works for both project-local installs (where pi
// loads from the workspace) and global npm installs (where pi loads
// from node_modules).
const EXT_DIR = dirname(__filename);
const SCRIPTS_DIR = resolve(EXT_DIR, "..", "scripts");

const CONTEXT_INJECT = join(SCRIPTS_DIR, "context-inject.sh");
const SESSION_START = join(SCRIPTS_DIR, "session-start.sh");

// Minimum pi.dev version this adapter supports. Bumped when we depend
// on a pi feature that didn't exist in older releases.
const MIN_PI_VERSION = "0.65.0";

// Run a bash script and return stdout as a string. Swallows non-zero
// exits silently — by design, lifecycle hooks must never block.
function runScript(scriptPath, args, cwd) {
  if (!existsSync(scriptPath)) return "";
  try {
    return execFileSync("bash", [scriptPath, ...args], {
      encoding: "utf8",
      cwd: cwd || process.cwd(),
      env: { ...process.env },
      timeout: 10000,
      maxBuffer: 1024 * 1024,
    });
  } catch (e) {
    // Hook failures are silent. Returning "" lets the LLM proceed with
    // whatever context it has — better than blocking the turn.
    return "";
  }
}

module.exports = function (pi) {
  // ── pi.on("context") — inject SDD state every turn ────────────
  // Equivalent to Claude Code's UserPromptSubmit hook. Surfaces the
  // active feature's spec.md, INDEX.md, principles.md, stack.md,
  // data-model.md, patterns.md inside trust-boundary markers so the
  // model sees current SDD state on every prompt without the user
  // having to re-paste it. Closes AC3.
  pi.on("context", async (event, ctx) => {
    const cwd = ctx && ctx.cwd ? ctx.cwd : process.cwd();
    if (!existsSync(join(cwd, ".sdd"))) return undefined;

    const injection = runScript(CONTEXT_INJECT, ["--project", cwd], cwd);
    if (!injection || !injection.trim()) return undefined;

    // Append the SDD state block to the latest user message so the
    // LLM sees it inside the same turn. pi-gsd uses the same pattern.
    const messages = (event && event.messages) || [];
    if (messages.length === 0) return undefined;

    const last = messages[messages.length - 1];
    if (!last || last.role !== "user") return undefined;

    if (typeof last.content === "string") {
      last.content = `${last.content}\n\n${injection}`;
    } else if (Array.isArray(last.content)) {
      last.content.push({ type: "text", text: injection });
    }

    return { messages };
  });

  // ── pi.on("session_start") — HRN-01 copy + worktree gate ──────
  // First-run install of the framework brain into .pi/sdd/ + a
  // version gate that refuses politely if pi is too old + a
  // worktree-config check (EC#4 from §15) that surfaces the
  // core.hooksPath conflict before commits silently bypass hooks.
  // Closes AC4.
  pi.on("session_start", async (_event, ctx) => {
    const cwd = ctx && ctx.cwd ? ctx.cwd : process.cwd();
    if (!existsSync(join(cwd, ".sdd"))) return undefined;

    // The session_start.sh script handles its own arg-validation and
    // is non-blocking on failure. We pass the bundled framework brain
    // location (extension's parent dir + "sdd-template") if it
    // exists; otherwise the user's existing .pi/sdd/ stays untouched.
    const fromCandidate = join(EXT_DIR, "..", "sdd-template");
    if (!existsSync(fromCandidate)) return undefined;

    runScript(
      SESSION_START,
      [
        "--project", cwd,
        "--from", fromCandidate,
        "--min-pi-version", MIN_PI_VERSION,
      ],
      cwd
    );
    return undefined;
  });

  // ── pi.registerCommand("sdd-status") — instant zero-LLM ───────
  // Closes AC7. Runs the project's bash .sdd/scripts/status.sh (no
  // model round-trip). Falls back to a documented message if no
  // .sdd/ project is initialised (EC#8 from §15).
  pi.registerCommand("sdd-status", {
    description: "Show the current SDD workflow state — phase, blocker, next action (instant)",
    handler: async (_args, ctx) => {
      const cwd = ctx && ctx.cwd ? ctx.cwd : process.cwd();
      const statusScript = join(cwd, ".sdd", "scripts", "status.sh");

      if (!existsSync(statusScript)) {
        ctx.ui.notify(
          "no SDD project found — run /sdd-start to initialise",
          "info"
        );
        return;
      }

      const out = runScript(statusScript, [], cwd);
      if (out && out.trim()) {
        ctx.ui.notify(out.trim(), "info");
      } else {
        ctx.ui.notify(
          "/sdd-status: status.sh produced no output (run `bash .sdd/scripts/status.sh` directly to debug)",
          "info"
        );
      }
    },
  });
};
