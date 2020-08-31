# Generate Helm repositories from submodules
#
# Copyright 2020 Andrei Kvapil
# SPDX-License-Identifier: Apache-2.0

# Source directory with submodules
SRC = sources
# Destination directory with public repository
DST = charts
# Specify which sources should be updated
WHAT ?= $(shell git ls-files ${SRC})
# Force regenerate packages if no changes detected
FORCE ?= 0
# Specify commit message
MSG = UPD $(shell date -R)
# Specify url for HELM repository
URL = https://kvaps.github.io/charts/


# Detect which submodules were changed
ALLSUBS = $(shell git ls-files ${SRC} --stage | awk '$$1 = "160000" {print $$NF}')
CHANGED = $(shell git status --short ${ALLSUBS} | awk '$$1 == "A" || $$1 == "M" {$$1 = ""; print $$0}')

ifdef WHAT
	ALLTARGETS = $(filter ${WHAT}%,${ALLSUBS})
	ifeq (${FORCE}, 1)
		TARGETS = $(filter ${WHAT}%,${ALLSUBS})
	else
		TARGETS = $(filter ${WHAT}%,${CHANGED})
	endif
else
	ALLTARGETS = ${ALLSUBS}
	ifeq (${FORCE}, 1)
		TARGETS = ${ALLSUBS}
	else
		TARGETS = ${CHANGED}
	endif
endif

.PHONY: all pull packages index commit push

all: pull packages index commit push

check:
	[ -n "${ALLTARGETS}" ]

pull: check
	git submodule update --init ${DST}; \
	git submodule update --init --remote ${ALLTARGETS}

packages: check
	for i in ${TARGETS}; do \
		dst="$$(dirname "$$i" | sed 's|^${SRC}|${DST}|')"; \
	  for p in $$(cd $$i; git ls-files | sed -n 's|Chart.yaml$$|./|p'); do \
		  (cd "$$i" && git submodule update --init --recursive); \
	    src=$$i/$$p; \
		  helm package "$$src" -d "$$dst/tmp/"; \
		done; \
	  mv -vn "$$dst/tmp/"* "$$dst/"; \
	  rm -vrf "$$dst/tmp/"; \
	done

index: check
	for i in ${TARGETS}; do \
		echo "$$(dirname "$$i" | sed 's|^${SRC}|${DST}|')"; \
	done | sort -u | while read i; do \
    mkdir -p "$$i/tmp"; \
    find "$$i" -maxdepth 1 -mindepth 1 -name "*.tgz" -exec mv {} "$$i/tmp/" \; ; \
    helm repo index --url "${URL}$$(echo "$$i" | sed 's|^${DST}||')/" "$$i/tmp"; \
    find "$$i/tmp" -mindepth 1 -exec mv {} "$$i/" \; ; \
    rmdir "$$i/tmp"; \
	done

commit:
	(cd ${DST} && git add . && git diff --quiet --exit-code --cached && exit 0 || git commit -m "${MSG}"); \
	git add .gitmodules charts/ sources/; \
	git diff --quiet --exit-code --cached && exit 0 || git commit -m "${MSG}"

push:
	(cd ${DST} && git push); \
	git push
