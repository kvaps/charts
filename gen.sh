#!/bin/sh
# Generate Helm repositories from submodules
#
# Copyright 2020 Andrei Kvapil
# SPDX-License-Identifier: Apache-2.0

set -e
FORCE=${FORCE:-0}
NOPUSH=${NOPUSH:-0}

options=$(getopt -o fn -- "$@")
eval set -- "$options"
while true; do
    case "$1" in
    -f)
        FORCE=1
        ;;
    -n)
        NOPUSH=1
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

cd $(dirname $0)

sources=$(echo ${@:-sources/} | grep sources)
repos=$(git ls-files $sources --stage | awk '$1 = "160000" {print $NF}')
if [ "$FORCE" = 1 ]; then
  changed="$repos"
else
  changed="$(git status --short $sources | awk '$1 == "A" || $1 == "M" {$1 = "";print $0}')"
fi

echo "=== Updating repos ==="
git submodule update --init --remote sources
echo "$repos" | while read i; do
  (
    echo "$i"
    cd "$i"
    git submodule update --init --recursive
  )
done

if [ -z "$changed" ]; then
  echo "noting to do"
  exit 0
fi

echo "=== Generating packages ==="
for i in $changed; do
  (cd "$i"; git ls-files | grep 'Chart.yaml$') | while read j; do
  chart=$(dirname ${i}/${j})
    echo "Packing $chart"
    helm package -d "$(dirname "$i" | sed 's/^sources/charts/')" "$chart"
  done
done

echo "=== Generating index ==="
find charts -type d | grep -v .git | while read i; do
  echo "$i"
  # avoid recursive index generation
  mkdir -p "$i/tmp"
  find "$i" -maxdepth 1 -mindepth 1 -name "*.tgz" -exec mv {} "$i/tmp/" \;
  helm repo index --url "https://kvaps.github.io/$i/" "$i/tmp"
  find "$i/tmp" -mindepth 1 -exec mv {} "$i/" \;
  rmdir "$i/tmp"
done

if [ "$NOPUSH" = 1 ]; then
  exit 0
fi

msg="UPD $(date -R)"

echo "=== Commiting charts ==="
(
  cd charts/
  git add .
  git commit -m "$msg"
  git push
)

echo "=== Commiting sources ==="
git add .gitmodules charts/ sources/
git commit -m "$msg"
git push
