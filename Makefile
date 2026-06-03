APP      := Respite
BUILD    := ./build
PRODUCT  := $(BUILD)/Build/Products/Release/$(APP).app
LAUNCHER := $(HOME)/.local/bin/respite

.PHONY: build install launcher run uninstall test clean

## build the Release .app
build:
	xcodebuild -project $(APP).xcodeproj -scheme $(APP) -configuration Release \
		-derivedDataPath $(BUILD) build CODE_SIGNING_ALLOWED=NO

## build, copy to /Applications, add `respite` launcher
install: build launcher
	rm -rf /Applications/$(APP).app
	cp -R "$(PRODUCT)" /Applications/
	@echo "Installed. Run with: respite"

launcher:
	@mkdir -p $(dir $(LAUNCHER))
	@printf '#!/bin/sh\nexec open /Applications/%s.app "$$@"\n' "$(APP)" > $(LAUNCHER)
	@chmod +x $(LAUNCHER)

## launch the installed app
run:
	open /Applications/$(APP).app

## remove app and launcher
uninstall:
	rm -rf /Applications/$(APP).app $(LAUNCHER)

test:
	xcodebuild -project $(APP).xcodeproj -scheme $(APP) test

clean:
	rm -rf $(BUILD)
