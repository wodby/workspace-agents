#!/usr/bin/env bash
# Pins agent releases in versions.env and records their verified SHA-256 checksums in checksums.txt.
#
# Versions default to Claude Code's stable channel and the latest GitHub releases of the other tools.
# Override any of them, for example: CODEX_VERSION=0.157.1 scripts/update.sh
#
# Claude Code checksums come from its release manifest, verified against Anthropic's signing key in
# keys/claude-code.asc. The other checksums come from GitHub's asset digests, cross-checked with the
# project's own checksum files where it publishes them.

set -euo pipefail

cd "$(dirname "$0")/.."

CLAUDE_CODE_KEY_FINGERPRINT="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"
CLAUDE_CODE_CHANNEL="${CLAUDE_CODE_CHANNEL:-stable}"
claude_url="https://downloads.claude.ai/claude-code-releases"

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

github() {
    curl -fsSL -H "Accept: application/vnd.github+json" ${GITHUB_TOKEN:+-H "Authorization: Bearer ${GITHUB_TOKEN}"} "https://api.github.com/repos/$1"
}

latest_tag() {
    github "$1/releases/latest" | jq -r .tag_name
}

# asset_digest REPO TAG ASSET prints the SHA-256 GitHub recorded for a release asset.
asset_digest() {
    local digest
    digest="$(github "$1/releases/tags/$2" | jq -r --arg name "$3" '.assets[] | select(.name == $name) | .digest')"
    if [[ "${digest}" != sha256:* ]]; then
        echo "No SHA-256 digest for $3 in $1 $2" >&2
        exit 1
    fi
    echo "${digest#sha256:}"
}

CLAUDE_CODE_VERSION="${CLAUDE_CODE_VERSION:-$(curl -fsSL "${claude_url}/${CLAUDE_CODE_CHANNEL}")}"
CODEX_VERSION="${CODEX_VERSION:-$(latest_tag openai/codex | sed 's/^rust-v//')}"
OPENCODE_VERSION="${OPENCODE_VERSION:-$(latest_tag anomalyco/opencode | sed 's/^v//')}"
RIPGREP_VERSION="${RIPGREP_VERSION:-$(latest_tag BurntSushi/ripgrep)}"

# Verify the Claude Code manifest signature with the pinned key before trusting its checksums.
export GNUPGHOME="${tmp}/gnupg"
mkdir -m 700 "${GNUPGHOME}"
gpg --batch --quiet --import keys/claude-code.asc
if ! gpg --batch --with-colons --fingerprint | grep -q "^fpr:::::::::${CLAUDE_CODE_KEY_FINGERPRINT}:"; then
    echo "keys/claude-code.asc is not the Claude Code release key ${CLAUDE_CODE_KEY_FINGERPRINT}" >&2
    exit 1
fi
curl -fsSL -o "${tmp}/manifest.json" "${claude_url}/${CLAUDE_CODE_VERSION}/manifest.json"
curl -fsSL -o "${tmp}/manifest.json.sig" "${claude_url}/${CLAUDE_CODE_VERSION}/manifest.json.sig"
gpg --batch --status-fd 1 --verify "${tmp}/manifest.json.sig" "${tmp}/manifest.json" 2>/dev/null \
    | grep -q "^\[GNUPG:\] VALIDSIG ${CLAUDE_CODE_KEY_FINGERPRINT} "

{
    for platform in linux-x64-musl linux-arm64-musl; do
        checksum="$(jq -r --arg p "${platform}" '.platforms[$p].checksum' "${tmp}/manifest.json")"
        echo "${checksum}  claude-${CLAUDE_CODE_VERSION}-${platform}"
    done

    codex_tag="rust-v${CODEX_VERSION}"
    curl -fsSL -o "${tmp}/codex.sums" "https://github.com/openai/codex/releases/download/${codex_tag}/codex-package_SHA256SUMS"
    for target in x86_64-unknown-linux-musl aarch64-unknown-linux-musl; do
        asset="codex-package-${target}.tar.gz"
        checksum="$(asset_digest openai/codex "${codex_tag}" "${asset}")"
        if ! grep -Eq "^${checksum}[[:space:]]+\*?${asset}\$" "${tmp}/codex.sums"; then
            echo "${asset} digest does not match codex-package_SHA256SUMS" >&2
            exit 1
        fi
        echo "${checksum}  codex-package-${CODEX_VERSION}-${target}.tar.gz"
    done

    for platform in linux-x64-musl linux-arm64-musl; do
        asset="opencode-${platform}.tar.gz"
        echo "$(asset_digest anomalyco/opencode "v${OPENCODE_VERSION}" "${asset}")  opencode-${OPENCODE_VERSION}-${platform}.tar.gz"
    done

    for target in x86_64-unknown-linux-musl aarch64-unknown-linux-musl; do
        asset="ripgrep-${RIPGREP_VERSION}-${target}.tar.gz"
        checksum="$(asset_digest BurntSushi/ripgrep "${RIPGREP_VERSION}" "${asset}")"
        published="$(curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/${asset}.sha256" | awk '{print $1}')"
        if [[ "${published}" != "${checksum}" ]]; then
            echo "${asset} digest does not match its .sha256 file" >&2
            exit 1
        fi
        echo "${checksum}  ${asset}"
    done
} > "${tmp}/checksums.txt"

mv "${tmp}/checksums.txt" checksums.txt
cat > versions.env <<VERSIONS
# Pinned agent releases. Run scripts/update.sh to move to newer releases and refresh checksums.txt.
CLAUDE_CODE_VERSION=${CLAUDE_CODE_VERSION}
CODEX_VERSION=${CODEX_VERSION}
OPENCODE_VERSION=${OPENCODE_VERSION}
RIPGREP_VERSION=${RIPGREP_VERSION}
VERSIONS

cat versions.env
