#!/usr/bin/env bash
# Releases use semantic versions: the major version is the runner contract (installer, wrappers and
# layout), the minor version adds tools or features, and the patch version updates tools or fixes.

set -euo pipefail

tag="${GITHUB_REF_NAME:?Missing release tag}"
if [[ "${GITHUB_REF:-}" != "refs/tags/${tag}" || ! "${tag}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo >&2 "Refusing non-semantic release tag: ${tag}"
    exit 1
fi
