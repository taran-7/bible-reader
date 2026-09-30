// NFR-1 (platform) and NFR-5 (size): a fresh Release build of the app is checked for
// the minimum macOS, the architecture (arm64 only, owner decision 2026-09-27) and the .app size.
// It always builds: checking an old build from build/ could give a false PASS.
//
// Usage: node scripts/check-platform.mjs
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

// The same limits are in Tests/BibleCoreTests/PlatformTests.swift and docs/requirements.md (NFR-1, NFR-5).
const MIN_MACOS = "14.0";
const ARCHS = ["arm64"];
const SIZE_LIMIT_MB = 100;
const SIZE_WARN_MB = 80;

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const DERIVED = join(ROOT, "build/platform");
const APP = join(DERIVED, "Build/Products/Release/Bible Reader.app");

const failures = [];
const warnings = [];
const run = (cmd, args) => execFileSync(cmd, args, { cwd: ROOT, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();
const finish = (scope) => {
  for (const w of warnings) console.warn(`WARN  ${w}`);
  for (const f of failures) console.error(`FAIL  ${f}`);
  console.log(`Scope: ${scope} platform check(s)`);
  console.log(`Result: ${failures.length ? "FAIL" : "PASS"}${warnings.length ? `, ${warnings.length} warning(s)` : ""}`);
  process.exit(failures.length ? 1 : 0);
};

try {
  run("xcodebuild", [
    "-quiet", "-project", "BibleReaderApp/BibleReader.xcodeproj", "-scheme", "BibleReader",
    "-configuration", "Release", "-derivedDataPath", DERIVED, "build",
  ]);
} catch (error) {
  console.error(String(error.stdout ?? "") + String(error.stderr ?? ""));
  failures.push("Release build failed");
  finish(0);
}
if (!existsSync(APP)) {
  failures.push(`${APP} not found after the build`);
  finish(0);
}

// 1. Minimum macOS: in project.yml and in the built app's Info.plist.
const yml = readFileSync(join(ROOT, "BibleReaderApp/project.yml"), "utf8");
const target = yml.match(/deploymentTarget:\s*\n\s*macOS:\s*"?([\d.]+)"?/)?.[1];
if (target !== MIN_MACOS) failures.push(`project.yml deploymentTarget.macOS = ${target}, expected ${MIN_MACOS}`);
const plistMin = run("/usr/libexec/PlistBuddy", ["-c", "Print :LSMinimumSystemVersion", join(APP, "Contents/Info.plist")]);
if (plistMin !== MIN_MACOS) failures.push(`Info.plist LSMinimumSystemVersion = ${plistMin}, expected ${MIN_MACOS}`);
console.log(`INFO  macOS minimum: project.yml ${target}, Info.plist ${plistMin}`);

// 2. Architecture: exactly arm64, no universal binary.
const archs = run("lipo", ["-archs", join(APP, "Contents/MacOS/Bible Reader")]).split(/\s+/).sort();
if (archs.join(" ") !== ARCHS.join(" ")) failures.push(`binary architectures [${archs}], expected exactly [${ARCHS}]`);
console.log(`INFO  architectures: ${archs.join(", ")}`);

// 3. Size.
const sizeMB = Number(run("du", ["-sk", APP]).split(/\s+/)[0]) / 1024;
if (!Number.isFinite(sizeMB) || sizeMB <= 0) failures.push(`cannot measure .app size (du gave ${sizeMB})`);
else if (sizeMB >= SIZE_LIMIT_MB) failures.push(`.app is ${sizeMB.toFixed(1)} MB, limit ${SIZE_LIMIT_MB} MB`);
else if (sizeMB >= SIZE_WARN_MB) warnings.push(`.app is ${sizeMB.toFixed(1)} MB, approaching the ${SIZE_LIMIT_MB} MB limit`);
console.log(`INFO  .app size: ${sizeMB.toFixed(1)} MB (limit ${SIZE_LIMIT_MB}, warn ${SIZE_WARN_MB})`);

finish(3);
