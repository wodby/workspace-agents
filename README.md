# Workspace Agents Docker Image

[![Build Status](https://github.com/wodby/workspace-agents/workflows/Build%20docker%20image/badge.svg)](https://github.com/wodby/workspace-agents/actions)
[![Docker Pulls](https://img.shields.io/docker/pulls/wodby/workspace-agents.svg)](https://hub.docker.com/r/wodby/workspace-agents)

Coding agent command-line tools for [Wodby development workspaces](https://wodby.com/docs/2.0/apps/workspaces/). A
workspace copies them in when its SSH runner starts, so `claude`, `codex` and `opencode` are ready to run after you
connect.

## Contents

| Command | Tool | Notes |
| --- | --- | --- |
| `claude` | [Claude Code](https://code.claude.com) | Not included in the image. The first run downloads the pinned build from Anthropic into your private home and verifies its checksum. |
| `codex` | [Codex CLI](https://github.com/openai/codex) | Static build; runs on any Linux runtime image. |
| `opencode` | [opencode](https://opencode.ai) | |

Versions are pinned in [versions.env](versions.env). The image also includes [ripgrep](https://github.com/BurntSushi/ripgrep)
for the agents' searches, and the `libstdc++` and `libgcc` libraries that Claude Code and opencode need. The agents
use these libraries only when the runtime image doesn't have them.

Claude Code and opencode are musl builds for Alpine-based runtime images. On other images they exit with a message,
and you can install them yourself.

## How workspaces use the image

1. The installer copies the tools into an empty volume: `wodby-agents-install /opt/wodby/agents`. It runs as the
   workspace user without privileges.
2. The SSH runner mounts the volume read-only at `/opt/wodby/agents`, and each command from `bin/` at
   `/usr/local/bin/<command>`, so login shells find them.
3. A new image reaches a workspace when its runner restarts. The bundled tools don't update themselves; install your
   own copy in `~/.local/bin` to manage versions yourself.

## Tags

* `1`, `latest`: builds of the `master` branch.
* `1-rN`: releases, from the `rN` git tags. Pin a release by digest.

All images are built for `linux/amd64` and `linux/arm64`.

## Updating the agents

```bash
make update
make
make test
```

`make update` pins Claude Code's stable release and the latest releases of the other tools, and records their
SHA-256 checksums in [checksums.txt](checksums.txt). The Claude Code checksums come from its release manifest after
checking the manifest's signature with Anthropic's release key in [keys/claude-code.asc](keys/claude-code.asc). The
other checksums come from GitHub's release asset digests, cross-checked with each project's own checksum files where
it publishes them. The image build and the Claude Code download both fail on a checksum mismatch.

## Licenses

The files in this repository are available under the [MIT license](LICENSE.md). The image redistributes third-party
software under its own licenses; see [licenses](licenses/README.md). Claude Code is subject to
[Anthropic's terms](https://code.claude.com/docs/en/legal-and-compliance).
