APP     := BetterSnap
BUNDLE  := $(APP).app
BUILD   := $(shell swift build -c release --arch arm64 --show-bin-path)
STAGE   := build/$(BUNDLE)
INSTALL := /Applications/$(BUNDLE)
IDENTITY := voice-assistant-dev

.PHONY: all build test bundle sign install run clean

all: bundle

build:
	swift build -c release --arch arm64

test:
	swift run BetterSnapTests

# Assemble the .app by hand. Xcode is not installed on this machine, and the
# Command Line Tools SDK ships AppKit, which is all this app needs.
bundle: build
	rm -rf $(STAGE)
	mkdir -p $(STAGE)/Contents/MacOS
	cp $(BUILD)/$(APP) $(STAGE)/Contents/MacOS/$(APP)
	cp Resources/Info.plist $(STAGE)/Contents/Info.plist
	$(MAKE) sign

sign:
	codesign --force --options runtime --sign "$(IDENTITY)" $(STAGE)
	codesign --verify --verbose $(STAGE)

install: bundle
	@pkill -x $(APP) || true
	rm -rf $(INSTALL)
	cp -R $(STAGE) $(INSTALL)
	@echo "Installed to $(INSTALL)"

# Always via `open`, never by exec'ing the binary: a direct exec does not register
# the app with LaunchServices, and both activation and the UserDefaults domain
# then misbehave.
run: install
	open $(INSTALL)

clean:
	rm -rf .build build
