## 1. Мережа (NFR-2)

- [x] 1.1 Тест `NetworkIsolationTests`: на фікстурі з `URLSession` падає з файлом і рядком; на реальних `Sources/` і `BibleReaderApp/Sources/` — зелений

## 2. Платформа і розмір (NFR-1, NFR-5)

- [x] 2.1 `ARCHS: arm64` у `project.yml`
- [x] 2.2 `scripts/check-platform.mjs`: Release-збірка, macOS 14.0 у `project.yml` і `Info.plist`, `arm64`, розмір < 100 МБ (WARN від 80)
- [x] 2.3 `qa-verify` і CI запускають `check-platform` (`Refs: PD-12`); запис PD-12 у `docs/project-factory.md`

## 3. Документи і рев'ю

- [x] 3.1 PRD §7, `docs/requirements.md`: NFR-1 (лише Apple Silicon), NFR-5 (< 100 МБ); tech debt #22 закрито
- [ ] 3.2 Рев'ю; NFR-1, NFR-2, NFR-5 → MVP; архів
