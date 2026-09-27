# Third-party licenses

This image redistributes the following software unchanged. Each directory holds its license.

| Component | License | Source |
| --- | --- | --- |
| Codex CLI, including `codex-code-mode-host` and its bundled ripgrep | Apache-2.0, see `codex/LICENSE` and `codex/NOTICE` | https://github.com/openai/codex |
| Bubblewrap (`codex-resources/bwrap`, shipped in the Codex package) | LGPL-2.1-or-later, see `bubblewrap/COPYING` | https://github.com/containers/bubblewrap |
| opencode | MIT, see `opencode/LICENSE` | https://github.com/anomalyco/opencode |
| ripgrep | MIT or Unlicense, see `ripgrep/` | https://github.com/BurntSushi/ripgrep |
| libstdc++ and libgcc from Alpine Linux | GPL-3.0-or-later with the GCC Runtime Library Exception, see `gcc/` | https://gcc.gnu.org and https://pkgs.alpinelinux.org |

Claude Code is not included. Its wrapper downloads the pinned build from Anthropic on first use. Claude Code
is subject to Anthropic's terms: https://code.claude.com/docs/en/legal-and-compliance
