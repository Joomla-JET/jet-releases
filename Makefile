MODULE ?= mod_joomlaboot_carousel

.PHONY: build build-module clean

build build-module:
	@bash scripts/build-module.sh $(MODULE)

clean:
	@rm -rf build/releases
	@echo "Cleaned build/releases"
