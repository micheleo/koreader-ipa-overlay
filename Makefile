DOCKER := docker run --rm -v "$(CURDIR)":/w -w /w alpine sh -c

test:
	$(DOCKER) "apk add -q luajit && luajit tests/run.lua"

lint:
	$(DOCKER) "apk add -q luacheck ruff && luacheck . && ruff check tools"

.PHONY: test lint

# Smoke test in the KOReader Linux emulator. BOOK_DIR holds a public domain epub named book.epub, screenshots go to OUT_DIR.
emulator:
	docker build -q -t ipaoverlay-emu tests/emulator
	docker run --rm -e BOOK=/books/book.epub -e WIDTH -e HEIGHT -e DPI -e VARIANT -e PAGES -v "$(BOOK_DIR)":/books -v "$(OUT_DIR)":/out \
		-v "$(CURDIR)/tests/emulator/run.sh":/run.sh -v "$(CURDIR)/ipaoverlay.koplugin":/opt/lib/koreader/plugins/ipaoverlay.koplugin ipaoverlay-emu /run.sh

.PHONY: emulator
