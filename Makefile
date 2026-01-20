# Derived values (DO NOT TOUCH).
CURRENT_MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
CURRENT_MAKEFILE_DIR := $(patsubst %/,%,$(dir $(CURRENT_MAKEFILE_PATH)))

.DEFAULT_GOAL := help
.PHONY: serve build-ghostty-xcframework

help:  # Display this help.
	@-+echo "Run make with one of the following targets:"
	@-+echo
	@-+grep -Eh "^[a-z-]+:.*#" $(CURRENT_MAKEFILE_PATH) | sed -E 's/^(.*:)(.*#+)(.*)/  \1 @@@ \3 /' | column -t -s "@@@"

build-ghostty-xcframework: # Build ghostty framework
	@cd $(CURRENT_MAKEFILE_DIR) && git submodule update --init --recursive
	@cd $(CURRENT_MAKEFILE_DIR) && mise install
	@cd $(CURRENT_MAKEFILE_DIR)/ThirdParty/ghostty && mise exec -- zig build -Doptimize=ReleaseFast -Demit-xcframework=true -Dsentry=false
	@cd $(CURRENT_MAKEFILE_DIR) && rsync -a ThirdParty/ghostty/macos/GhosttyKit.xcframework Frameworks
