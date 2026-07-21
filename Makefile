MODULES := $(notdir $(patsubst %/,%,$(wildcard repos/modules/*/)))
COMPONENTS := $(notdir $(patsubst %/,%,$(wildcard repos/components/*/)))
TEMPLATES := $(notdir $(patsubst %/,%,$(wildcard repos/templates/*/)))
BASE_URL ?= https://joomla-jet.github.io/jet-releases

export BASE_URL

.PHONY: all build verify publish publish-dry-run release list clean

all: build

build:
	@bash scripts/build-release.sh "$(EXTENSION)"

verify:
	@python3 scripts/verify-release.py "$(EXTENSION)"

publish:
	@EXTENSION="$(EXTENSION)" DRY_RUN="$(DRY_RUN)" bash scripts/publish-release.sh

publish-dry-run:
	@EXTENSION="$(EXTENSION)" DRY_RUN=1 bash scripts/publish-release.sh

release: build verify publish

list:
	@python3 scripts/list-extensions.py

clean:
	@rm -rf build/releases
	@echo "Cleaned build/releases"
