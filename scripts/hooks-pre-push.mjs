// Git pre-push hook: secret scanner over commits not yet on the remote.
// Pre-commit sees only its own commit; a commit with --no-verify, a cherry-pick or a rebase bypass it,
// and CI catches a key only once it is on GitHub. This is the last chance before publishing (PD-19).
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";

const ZERO = /^0+$/;

/** git log ranges for pre-push stdin lines: `<local ref> <local sha> <remote ref> <remote sha>`. */
export function pushRanges(stdin, remote) {
  return stdin.split("\n").filter(Boolean).flatMap((line) => {
    const [, localSha, , remoteSha] = line.split(" ");
    if (!localSha || ZERO.test(localSha)) return []; // a branch delete
    // A new branch: everything not in any branch of the remote.
    return [ZERO.test(remoteSha) ? [localSha, "--not", `--remotes=${remote}`] : [`${remoteSha}..${localSha}`]];
  });
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const ranges = pushRanges(readFileSync(0, "utf8"), process.argv[2] ?? "origin");
  for (const range of ranges) {
    const result = spawnSync(process.execPath, ["scripts/check-secrets.mjs", "--history", ...range], { stdio: "inherit" });
    if (result.status !== 0) {
      console.error("pre-push: the commits being pushed look like they contain a secret — API keys belong only in the Keychain. Push aborted.");
      process.exit(1);
    }
  }
}
