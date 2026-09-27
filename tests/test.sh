#!/usr/bin/env bash
# Installs the agents like a workspace runner does and runs them in runtime images.
#
# The installer runs as a non-root user into an empty volume. Runtime containers mount the volume
# read-only at /opt/wodby/agents and each wrapper into /usr/local/bin, then run the agents in a login
# shell, which resets PATH on Alpine.

set -euo pipefail

if [[ -n "${DEBUG:-}" ]]; then
    set -x
fi

IMAGE="${IMAGE:-wodby/workspace-agents}"
volume="workspace-agents-test-$$"
# The private home persists across runner restarts, like the workspace home volume.
home="workspace-agents-home-$$"

cleanup() {
    docker volume rm -f "${volume}" "${home}" >/dev/null
}
trap cleanup EXIT

docker volume create "${volume}" >/dev/null
docker volume create "${home}" >/dev/null
# Kubernetes gives the runner's group write access to an emptyDir.
docker run --rm -v "${volume}:/opt/wodby/agents" -v "${home}:/home/wodby" alpine:3.24 chmod 0777 /opt/wodby/agents /home/wodby
docker run --rm --user 1000:1000 --read-only -v "${volume}:/opt/wodby/agents" "${IMAGE}"

mounts=(--mount "type=volume,src=${volume},dst=/opt/wodby/agents,readonly")
for agent in claude codex opencode; do
    mounts+=(--mount "type=volume,src=${volume},dst=/usr/local/bin/${agent},volume-subpath=bin/${agent},readonly")
done

run() {
    local image="$1"
    shift
    # The runner replaces the image's entrypoint too.
    docker run --rm --user 1000:1000 -e HOME=/home/wodby -v "${home}:/home/wodby" "${mounts[@]}" --entrypoint /bin/sh "${image}" -lc "$*"
}

# expect IMAGE COMMAND PATTERN runs COMMAND and requires PATTERN in its output.
expect() {
    local output
    output="$(run "$1" "$2" 2>&1)" || {
        echo "FAIL $1: $2" >&2
        echo "${output}" >&2
        exit 1
    }
    if ! grep -q -- "$3" <<<"${output}"; then
        echo "FAIL $1: $2 printed:" >&2
        echo "${output}" >&2
        exit 1
    fi
    echo "OK   $1: $2"
}

. ./versions.env

# The first Claude Code run downloads the pinned build into the private home; later runs reuse it.
expect alpine:3.24 "claude --version" "Downloading Claude Code ${CLAUDE_CODE_VERSION} from Anthropic"
expect alpine:3.24 "test -x ~/.local/share/wodby-agents/claude/${CLAUDE_CODE_VERSION}/claude && echo downloaded" "downloaded"
if run node:24-alpine "claude --version" 2>&1 | grep -q "Downloading"; then
    echo "FAIL node:24-alpine: claude downloaded again" >&2
    exit 1
fi
echo "OK   node:24-alpine: claude reuses the download"

# alpine lacks libstdc++ and libgcc, so the bundled copies are used. node:alpine and wodby/php have
# their own.
for image in alpine:3.24 node:24-alpine wodby/php:8.4; do
    expect "${image}" "claude --version" "${CLAUDE_CODE_VERSION}"
    expect "${image}" "codex --version" "${CODEX_VERSION}"
    expect "${image}" "opencode --version" "${OPENCODE_VERSION}"
done

# Bundled libraries are added only when the image lacks them, so the programs the agents run keep
# the image's own libraries.
libraries='root=/opt/wodby/agents; . "${root}/libexec/agent.sh"; echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-none}"'
expect node:24-alpine "${libraries}" "LD_LIBRARY_PATH=none"
expect alpine:3.24 "${libraries}" "LD_LIBRARY_PATH=/opt/wodby/agents/lib/libgcc_s:/opt/wodby/agents/lib/libstdc++"

# Codex is static. The musl builds refuse a glibc image with an explanation.
expect debian:bookworm-slim "codex --version" "${CODEX_VERSION}"
if run debian:bookworm-slim "claude --version" >/tmp/claude-glibc.$$ 2>&1; then
    echo "FAIL debian: claude ran on glibc" >&2
    exit 1
fi
grep -q "needs an Alpine-based runtime image" /tmp/claude-glibc.$$ && rm -f /tmp/claude-glibc.$$
echo "OK   debian:bookworm-slim: claude explains the Alpine requirement"
