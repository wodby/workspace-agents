#!/bin/sh
# Downloads the pinned agent builds for the target architecture, verifies them against checksums.txt
# and lays them out in /dist, the tree that wodby-agents-install copies into a workspace.
#
# Claude Code is not redistributed: its wrapper downloads the pinned build from Anthropic on first use,
# verified against the same checksums.txt.

set -eu

. ./versions.env

case "${TARGETARCH}" in
amd64) platform=linux-x64-musl; target=x86_64-unknown-linux-musl ;;
arm64) platform=linux-arm64-musl; target=aarch64-unknown-linux-musl ;;
*) echo "Unsupported architecture ${TARGETARCH}" >&2; exit 1 ;;
esac

# fetch URL FILE downloads FILE and fails unless checksums.txt has a matching entry for it.
fetch() {
    curl -fsSL --retry 3 -o "$2" "$1"
    line="$(awk -v file="$2" '$2 == file' checksums.txt)"
    if [ -z "${line}" ]; then
        echo "No checksum for $2 in checksums.txt" >&2
        exit 1
    fi
    echo "${line}" | sha256sum -c -
}

fetch "https://github.com/openai/codex/releases/download/rust-v${CODEX_VERSION}/codex-package-${target}.tar.gz" \
    "codex-package-${CODEX_VERSION}-${target}.tar.gz"
fetch "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-${platform}.tar.gz" \
    "opencode-${OPENCODE_VERSION}-${platform}.tar.gz"
fetch "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-${target}.tar.gz" \
    "ripgrep-${RIPGREP_VERSION}-${target}.tar.gz"

mkdir -p /dist/codex /dist/opencode /dist/path /dist/lib/libstdc++ /dist/lib/libgcc_s /tmp/extract

# Keep the Codex package layout: the binary finds its sandbox helper and ripgrep next to itself.
tar -xzof "codex-package-${CODEX_VERSION}-${target}.tar.gz" -C /dist/codex
test -x /dist/codex/bin/codex

tar -xzof "opencode-${OPENCODE_VERSION}-${platform}.tar.gz" -C /tmp/extract
install -m 0755 /tmp/extract/opencode /dist/opencode/opencode

tar -xzof "ripgrep-${RIPGREP_VERSION}-${target}.tar.gz" -C /tmp/extract
install -m 0755 "/tmp/extract/ripgrep-${RIPGREP_VERSION}-${target}/rg" /dist/path/rg

# Claude Code and opencode need these on musl. The wrappers use them only when a runtime image lacks them.
cp -L /usr/lib/libstdc++.so.6 /dist/lib/libstdc++/libstdc++.so.6
cp -L /usr/lib/libgcc_s.so.1 /dist/lib/libgcc_s/libgcc_s.so.1

cp versions.env checksums.txt /dist/
chmod -R a+rX /dist
