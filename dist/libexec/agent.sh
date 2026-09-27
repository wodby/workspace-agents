# Shared setup for the agent wrappers, sourced with $root set to the agents directory.
#
# Claude Code and opencode are musl builds. They need libstdc++ and libgcc from the runtime image;
# when the image lacks one, the bundled copy is added to LD_LIBRARY_PATH. Only missing libraries are
# added, so programs the agent runs keep using the image's own libraries.

if [ ! -e "/lib/ld-musl-$(uname -m).so.1" ]; then
    echo "${0##*/}: the pre-installed build needs an Alpine-based runtime image. Install it yourself instead." >&2
    exit 127
fi

for lib in libstdc++.so.6 libgcc_s.so.1; do
    if [ ! -e "/lib/${lib}" ] && [ ! -e "/usr/lib/${lib}" ] && [ ! -e "/usr/local/lib/${lib}" ]; then
        LD_LIBRARY_PATH="${root}/lib/${lib%%.so*}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
        export LD_LIBRARY_PATH
    fi
done

# ripgrep for the agent's searches, after the image's own tools.
case ":${PATH}:" in
*":${root}/path:"*) ;;
*) PATH="${PATH}:${root}/path" ;;
esac
export PATH
