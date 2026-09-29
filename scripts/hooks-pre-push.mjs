// Git pre-push hook: сканер секретів по комітах, яких ще немає на віддаленому репозиторії.
// Pre-commit бачить лише свій коміт; коміт з --no-verify, cherry-pick чи rebase проходять повз нього,
// а CI ловить ключ, коли він уже на GitHub. Тут — останній шанс до публікації (PD-19).
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";

const ZERO = /^0+$/;

/** Діапазони git log для рядків stdin pre-push: `<local ref> <local sha> <remote ref> <remote sha>`. */
export function pushRanges(stdin, remote) {
  return stdin.split("\n").filter(Boolean).flatMap((line) => {
    const [, localSha, , remoteSha] = line.split(" ");
    if (!localSha || ZERO.test(localSha)) return []; // видалення гілки
    // Нова гілка: усе, чого немає в жодній гілці віддаленого репозиторію.
    return [ZERO.test(remoteSha) ? [localSha, "--not", `--remotes=${remote}`] : [`${remoteSha}..${localSha}`]];
  });
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const ranges = pushRanges(readFileSync(0, "utf8"), process.argv[2] ?? "origin");
  for (const range of ranges) {
    const result = spawnSync(process.execPath, ["scripts/check-secrets.mjs", "--history", ...range], { stdio: "inherit" });
    if (result.status !== 0) {
      console.error("pre-push: у комітах для пушу схоже на секрет — ключі API лише в Keychain. Пуш скасовано.");
      process.exit(1);
    }
  }
}
