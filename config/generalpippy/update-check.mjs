#!/usr/bin/env node
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import readline from "node:readline/promises";
import { stdin as input, stdout as output } from "node:process";

const DEFAULT_MANIFEST_URL = "https://raw.githubusercontent.com/ChindanaiNaKub/generalPippy/main/manifest.json";
const CACHE_TTL_MS = 24 * 60 * 60 * 1000;
const PROMPT_TTL_MS = 24 * 60 * 60 * 1000;
const FETCH_TIMEOUT_MS = 2000;

export function generalPippyDir(env = process.env) {
  const configHome = env.XDG_CONFIG_HOME || path.join(env.HOME || os.homedir(), ".config");
  return path.join(configHome, "opencode", "generalpippy");
}

function readJson(file, fallback = null) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return fallback;
  }
}

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

function nowIso() {
  return new Date().toISOString();
}

function parseVersion(version) {
  const match = String(version || "").trim().match(/^v?(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$/);
  if (!match) return null;
  return match.slice(1, 4).map((part) => Number(part));
}

export function compareVersions(a, b) {
  const left = parseVersion(a);
  const right = parseVersion(b);
  if (!left || !right) return 0;
  for (let i = 0; i < 3; i += 1) {
    if (left[i] > right[i]) return 1;
    if (left[i] < right[i]) return -1;
  }
  return 0;
}

function detectOpenCodeVersion() {
  try {
    const raw = execFileSync("opencode", ["--version"], { encoding: "utf8", timeout: 1000 }).trim();
    const match = raw.match(/v?(\d+\.\d+\.\d+(?:[-+][^\s]+)?)/);
    return match ? match[1] : "";
  } catch {
    return "";
  }
}

async function fetchManifest(url, timeoutMs = FETCH_TIMEOUT_MS) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, { signal: controller.signal });
    if (!response.ok) throw new Error(`manifest fetch failed: ${response.status}`);
    return await response.json();
  } finally {
    clearTimeout(timer);
  }
}

function selectRelease(manifest, channel) {
  if (channel === "prerelease" && manifest.prerelease) return manifest.prerelease;
  return manifest.stable;
}

function shouldUseCachedManifest(state, force, ttlMs) {
  if (force || !state.manifest_cache || !state.last_checked_at) return false;
  const checkedAt = Date.parse(state.last_checked_at);
  return Number.isFinite(checkedAt) && Date.now() - checkedAt < ttlMs;
}

function shouldPromptForVersion(state, latestVersion) {
  if ((state.dismissed_versions || []).includes(latestVersion)) return false;
  if (state.last_prompted_version !== latestVersion || !state.last_prompted_at) return true;
  const promptedAt = Date.parse(state.last_prompted_at);
  return !Number.isFinite(promptedAt) || Date.now() - promptedAt >= PROMPT_TTL_MS;
}

export async function checkForUpdate(options = {}) {
  const env = options.env || process.env;
  const dir = options.dir || generalPippyDir(env);
  const settings = readJson(path.join(dir, "settings.json"), {});
  const statePath = path.join(dir, "update-state.json");
  const versionPath = path.join(dir, "version.json");
  const state = readJson(statePath, {});
  const installed = readJson(versionPath, {});

  if (env.GENERALPIPPY_UPDATE_CHECK === "0" || settings.update_check === false) {
    return { status: "disabled", enabled: false, installed_version: installed.version || "unknown" };
  }

  const channel = settings.update_channel === "prerelease" ? "prerelease" : "stable";
  const manifestUrl = options.manifestUrl || settings.manifest_url || DEFAULT_MANIFEST_URL;
  let manifest = null;
  let fromCache = false;

  if (shouldUseCachedManifest(state, Boolean(options.force), options.cacheTtlMs || CACHE_TTL_MS)) {
    manifest = state.manifest_cache;
    fromCache = true;
  } else {
    try {
      manifest = await fetchManifest(manifestUrl, options.timeoutMs || FETCH_TIMEOUT_MS);
      state.manifest_cache = manifest;
      state.last_checked_at = nowIso();
      writeJson(statePath, state);
    } catch (error) {
      if (state.manifest_cache) {
        manifest = state.manifest_cache;
        fromCache = true;
      } else {
        return {
          status: "offline",
          enabled: true,
          installed_version: installed.version || "unknown",
          error: error.message,
        };
      }
    }
  }

  const latest = selectRelease(manifest, channel);
  if (!latest || !latest.version) {
    return { status: "invalid_manifest", enabled: true, installed_version: installed.version || "unknown", channel };
  }

  const installedVersion = installed.version || "0.0.0";
  const updateAvailable = compareVersions(latest.version, installedVersion) > 0;
  const openCodeVersion = detectOpenCodeVersion();
  const minimumOpenCode = latest.minimum_opencode_version || "0.0.0";
  const compatible = openCodeVersion ? compareVersions(openCodeVersion, minimumOpenCode) >= 0 : null;

  return {
    status: updateAvailable ? "update_available" : "current",
    enabled: true,
    channel,
    from_cache: fromCache,
    installed_version: installed.version || "unknown",
    latest,
    update_available: updateAvailable,
    opencode_version: openCodeVersion || "unknown",
    minimum_opencode_version: minimumOpenCode,
    compatible,
    should_prompt: updateAvailable && shouldPromptForVersion(state, latest.version),
    install_command: `curl -fsSL ${latest.install_url || DEFAULT_MANIFEST_URL.replace("/manifest.json", "/install.sh")} | bash`,
  };
}

export function markPrompted(version, options = {}) {
  const dir = options.dir || generalPippyDir(options.env || process.env);
  const statePath = path.join(dir, "update-state.json");
  const state = readJson(statePath, {});
  state.last_prompted_version = version;
  state.last_prompted_at = nowIso();
  writeJson(statePath, state);
}

export function skipVersion(version, options = {}) {
  const dir = options.dir || generalPippyDir(options.env || process.env);
  const statePath = path.join(dir, "update-state.json");
  const state = readJson(statePath, {});
  const dismissed = new Set(state.dismissed_versions || []);
  dismissed.add(version);
  state.dismissed_versions = Array.from(dismissed).sort();
  writeJson(statePath, state);
}

export function formatUpdateNotice(result) {
  if (result.status === "disabled") return "GeneralPippy update checks are disabled.";
  if (result.status === "offline") return "GeneralPippy update check could not reach the manifest; continuing offline.";
  if (result.status === "current") return `GeneralPippy is current (${result.installed_version}).`;
  if (result.status !== "update_available") return `GeneralPippy update status: ${result.status}.`;

  const compatibility = result.compatible === false
    ? ` Requires OpenCode ${result.minimum_opencode_version}+; detected ${result.opencode_version}.`
    : result.compatible === null
      ? " OpenCode compatibility could not be verified."
      : "";

  return [
    `GeneralPippy ${result.latest.version} is available. Installed: ${result.installed_version}.`,
    compatibility.trim(),
    `Installer: ${result.install_command}`,
  ].filter(Boolean).join("\n");
}

async function main(argv) {
  const force = argv.includes("--force");
  const json = argv.includes("--json");
  const interactive = argv.includes("--interactive");
  const skip = argv.includes("--skip-version");
  const result = await checkForUpdate({ force });

  if (json) {
    console.log(JSON.stringify(result, null, 2));
    return;
  }

  console.log(formatUpdateNotice(result));

  if (skip && result.latest?.version) {
    skipVersion(result.latest.version);
    console.log(`Skipped GeneralPippy ${result.latest.version}.`);
    return;
  }

  if (interactive && result.status === "update_available" && result.compatible !== false) {
    markPrompted(result.latest.version);
    const rl = readline.createInterface({ input, output });
    const answer = await rl.question("Run installer now? (y/N) ");
    rl.close();
    if (/^y(es)?$/i.test(answer.trim())) {
      const child = spawnSync("bash", ["-lc", result.install_command], { stdio: "inherit" });
      process.exit(child.status ?? 1);
    }
    console.log("Update skipped.");
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(`GeneralPippy update check failed: ${error.message}`);
    process.exit(1);
  });
}
