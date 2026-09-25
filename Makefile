# Без Xcode (лише Command Line Tools) Swift Testing треба підключати явно.
CLT := /Library/Developer/CommandLineTools
ifeq ($(shell xcode-select -p),$(CLT))
FW := $(CLT)/Library/Developer/Frameworks
# _Testing_Foundation у CLT без swiftmodule, тому вимикаємо cross-import overlays.
TEST_FLAGS := -Xswiftc -F$(FW) -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays -Xlinker -F$(FW) -Xlinker -rpath -Xlinker $(FW) \
	-Xlinker -rpath -Xlinker $(CLT)/Library/Developer/usr/lib
endif

.PHONY: test db check

test:
	swift test $(TEST_FLAGS)

db:
	swift run bible-import data/raw BibleReaderApp/Resources/bible.sqlite

check: test
