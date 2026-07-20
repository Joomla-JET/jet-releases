MODULES := $(notdir $(patsubst %/,%,$(wildcard repos/modules/*/)))
COMPONENTS := $(notdir $(patsubst %/,%,$(wildcard repos/components/*/)))
TEMPLATES := $(notdir $(patsubst %/,%,$(wildcard repos/templates/*/)))
BASE_URL ?= https://example.com

export BASE_URL

.PHONY: all build release modules components templates build-module build-component build-template list clean

all build release: modules components templates

modules:
	@set -e; for extension in $(MODULES); do \
		bash scripts/build-extension.sh modules "$$extension"; \
	done

components:
	@set -e; for extension in $(COMPONENTS); do \
		bash scripts/build-extension.sh components "$$extension"; \
	done

templates:
	@set -e; for extension in $(TEMPLATES); do \
		bash scripts/build-extension.sh templates "$$extension"; \
	done

build-module:
	@test -n "$(MODULE)" || (echo "Usage: make build-module MODULE=mod_name"; exit 1)
	@bash scripts/build-extension.sh modules "$(MODULE)"

build-component:
	@test -n "$(COMPONENT)" || (echo "Usage: make build-component COMPONENT=com_name"; exit 1)
	@bash scripts/build-extension.sh components "$(COMPONENT)"

build-template:
	@test -n "$(TEMPLATE)" || (echo "Usage: make build-template TEMPLATE=tpl_name"; exit 1)
	@bash scripts/build-extension.sh templates "$(TEMPLATE)"

list:
	@echo "Modules:    $(MODULES)"
	@echo "Components: $(COMPONENTS)"
	@echo "Templates:  $(TEMPLATES)"

clean:
	@rm -rf build/releases
	@echo "Cleaned build/releases"
