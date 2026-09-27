# Без Xcode (лише Command Line Tools) Swift Testing треба підключати явно.
CLT := /Library/Developer/CommandLineTools
ifeq ($(shell xcode-select -p),$(CLT))
FW := $(CLT)/Library/Developer/Frameworks
# _Testing_Foundation у CLT без swiftmodule, тому вимикаємо cross-import overlays.
TEST_FLAGS := -Xswiftc -F$(FW) -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays -Xlinker -F$(FW) -Xlinker -rpath -Xlinker $(FW) \
	-Xlinker -rpath -Xlinker $(CLT)/Library/Developer/usr/lib
endif

.PHONY: test db check coverage ui-test

test:
	python3 scripts/test_convert_getbible.py
	swift test $(TEST_FLAGS)

DB := BibleReaderApp/Resources/bible.sqlite

# База перебудовується, коли змінилися тексти або код імпорту чи пошуку (схема).
db: $(DB)

$(DB): $(wildcard data/raw/*.json) $(wildcard Sources/BibleCore/*.swift) $(wildcard Sources/bible-import/*.swift) $(wildcard Sources/CSnowball/*/*.c)
	swift run bible-import data/raw $(DB)

check: test

# Покриття Sources/ для check-coverage-ratchet (див. scripts/swift-coverage-summary.mjs).
coverage:
	swift test --enable-code-coverage $(TEST_FLAGS)
	node scripts/swift-coverage-summary.mjs

# Збірка додатка і XCUITest (Tests/BibleReaderUITests). Локально потрібен Automation Mode
# (перший запуск просить підтвердження; або `sudo automationmodetool enable-automationmode-without-authentication`).
ui-test:
	xcodebuild test -project BibleReaderApp/BibleReader.xcodeproj -scheme BibleReader -destination 'platform=macOS'
