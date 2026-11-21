#!/usr/bin/env bash
# Rewrites the cargo feature list in upstream Stalwart's Dockerfile so that we
# build only the features we want (no enterprise, no extra stores), using ThinLTO
# for reduced memory consumption on the runner
#
# Usage: patch-dockerfile.sh <path/to/Dockerfile> "<features>"
#
# Fails loudly if upstream changes the Dockerfile layout in a way we no longer
# recognise, rather than silently shipping a default (enterprise) build.
set -euo pipefail

dockerfile="${1:?usage: $0 <Dockerfile> <features>}"
features="${2:?usage: $0 <Dockerfile> <features>}"

if ! [[ "$features" =~ ^[a-z0-9_\ -]+$ ]]; then
    echo "error: refusing odd-looking feature list: '$features'" >&2
    exit 1
fi

# Both the cargo-chef 'cook' step and the 'cargo build' step must carry the
# feature list, otherwise the dependency cache layer is useless.
for step in 'cargo chef cook' 'cargo build'; do
    if ! grep -E "$step" "$dockerfile" | grep -q -- '--no-default-features --features "'; then
        echo "error: '$step' line with --no-default-features --features \"...\" not found in $dockerfile" >&2
        echo "       upstream Dockerfile layout has changed; update this script." >&2
        exit 1
    fi
done

sed -E -i "s/--features \"[^\"]*\"/--features \"${features}\"/g" "$dockerfile"

# Override upstream's fat LTO for both dependency cooking and the final build.
# Keep these settings identical so the cooked dependencies can be reused.
sed -E -i '/CARGO_PROFILE_RELEASE_LTO=thin/! s/(cargo chef cook|cargo build)/CARGO_PROFILE_RELEASE_LTO=thin \1/' "$dockerfile"

# Sanity checks on the result.
if grep -n -- '--features' "$dockerfile" | grep -v -- "--features \"${features}\""; then
    echo "error: unpatched --features occurrences remain (above)" >&2
    exit 1
fi
if [[ " $features " != *" enterprise "* ]] && grep -n 'enterprise' "$dockerfile"; then
    echo "error: 'enterprise' still referenced in $dockerfile (above)" >&2
    exit 1
fi

echo "Patched $dockerfile with features: $features"
grep -n -- '--features' "$dockerfile"
