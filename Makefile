MODULES := $(notdir $(patsubst %/,%,$(wildcard repos/modules/*/)))
COMPONENTS := $(notdir $(patsubst %/,%,$(wildcard repos/components/*/)))
TEMPLATES := $(notdir $(patsubst %/,%,$(wildcard repos/templates/*/)))
BASE_URL ?= https://example.com

export BASE_URL

.PHONY: all build verify publish release list clean

all: build

build:
	@bash scripts/build-release.sh "$(EXTENSION)"

verify:
	@python3 scripts/verify-release.py "$(EXTENSION)"

publish:
	@EXTENSION="$(EXTENSION)" DRY_RUN="$(DRY_RUN)" bash scripts/publish-release.sh

release:
	@bash scripts/build-release.sh "$(EXTENSION)"
	@EXTENSION="$(EXTENSION)" DRY_RUN="$(DRY_RUN)" bash scripts/publish-release.sh

list:
	@echo "Modules:    $(MODULES)"
	@echo "Components: $(COMPONENTS)"
	@echo "Templates:  $(TEMPLATES)"

clean:
	@rm -rf build/releases
	@echo "Cleaned build/releases"
