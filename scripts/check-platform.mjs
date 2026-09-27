// NFR-1 (платформа) і NFR-5 (розмір): Release-збірка додатка перевіряється на
// мінімальну macOS, архітектуру arm64 і розмір .app.
//
// Usage:
//   node scripts/check-platform.mjs              # зібрати Release у build/platform і перевірити
//   node scripts/check-platform.mjs --skip-build # перевірити вже зібраний build/platform
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";

const MIN_MACOS = "14.0";
const REQUIRED_ARCH = "arm64";
const SIZE_LIMIT_MB = 100;
const SIZE_WARN_MB = 80;
const DERIVED = "build/platform";
const APP = `${DERIVED}/Build/Products/Release/Bible Reader.app`;

const failures = [];
const warnings = [];
const run = (cmd, args) => execFileSync(cmd, args, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();

if (!process.argv.includes("--skip-build")) {
  run("xcodebuild", [
    "-quiet", "-project", "BibleReaderApp/BibleReader.xcodeproj", "-scheme", "BibleReader",
    "-configuration", "Release", "-derivedDataPath", DERIVED, "build",
  ]);
}
if (!existsSync(APP)) {
  console.error(`FAIL  ${APP} not found — nothing to check`);
  console.log("Scope: 0 platform check(s)");
  console.log("Result: FAIL");
  process.exit(1);
}

// 1. Мінімальна macOS: у project.yml і в Info.plist зібраного додатка.
const yml = readFileSync("BibleReaderApp/project.yml", "utf8");
const target = yml.match(/deploymentTarget:\s*\n\s*macOS:\s*"([\d.]+)"/)?.[1];
if (target !== MIN_MACOS) failures.push(`project.yml deploymentTarget.macOS = ${target}, expected ${MIN_MACOS}`);
const plistMin = run("/usr/libexec/PlistBuddy", ["-c", "Print :LSMinimumSystemVersion", `${APP}/Contents/Info.plist`]);
if (plistMin !== MIN_MACOS) failures.push(`Info.plist LSMinimumSystemVersion = ${plistMin}, expected ${MIN_MACOS}`);
console.log(`INFO  macOS minimum: project.yml ${target}, Info.plist ${plistMin}`);

// 2. Архітектура.
const archs = run("lipo", ["-archs", `${APP}/Contents/MacOS/Bible Reader`]).split(/\s+/);
if (!archs.includes(REQUIRED_ARCH)) failures.push(`binary architectures [${archs}] lack ${REQUIRED_ARCH}`);
console.log(`INFO  architectures: ${archs.join(", ")}`);

// 3. Розмір.
const sizeMB = Number(run("du", ["-sk", APP]).split(/\s+/)[0]) / 1024;
if (sizeMB >= SIZE_LIMIT_MB) failures.push(`.app is ${sizeMB.toFixed(1)} MB, limit ${SIZE_LIMIT_MB} MB`);
else if (sizeMB >= SIZE_WARN_MB) warnings.push(`.app is ${sizeMB.toFixed(1)} MB, approaching the ${SIZE_LIMIT_MB} MB limit`);
console.log(`INFO  .app size: ${sizeMB.toFixed(1)} MB (limit ${SIZE_LIMIT_MB}, warn ${SIZE_WARN_MB})`);

for (const w of warnings) console.warn(`WARN  ${w}`);
for (const f of failures) console.error(`FAIL  ${f}`);
console.log("Scope: 3 platform check(s)");
console.log(`Result: ${failures.length ? "FAIL" : "PASS"}${warnings.length ? `, ${warnings.length} warning(s)` : ""}`);
process.exit(failures.length ? 1 : 0);
