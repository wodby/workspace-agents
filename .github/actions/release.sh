#!/usr/bin/env bash

set -exo pipefail

version="$(make -s -f Makefile -f - <<<'print-version: ; @echo $(VERSION)' print-version)"

if [[ "${GITHUB_REF}" == refs/heads/master || "${GITHUB_REF}" == refs/tags/* ]]; then
  tags=("${version}" "latest")

  if [[ "${GITHUB_REF}" == refs/tags/* ]]; then
    stability_tag="${GITHUB_REF##*/}"
    tags=("${version}-${stability_tag}")
  fi

  for tag in "${tags[@]}"; do
    make buildx-imagetools-create IMAGETOOLS_TAG="${tag}"
  done
fi
