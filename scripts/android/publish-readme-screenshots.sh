#!/usr/bin/env bash
set -euo pipefail

prepared="${1:?Usage: publish-readme-screenshots.sh PREPARED SOURCE_CHECKOUT WORKTREE}"
source_checkout="${2:?Source checkout with an authenticated origin is required.}"
publication="${3:?A new worktree path is required.}"
[[ -d "$prepared/android" && -f "$prepared/README.md" ]] || {
    echo 'Prepare a complete screenshot gallery before publishing.' >&2
    exit 1
}

set +e
git -C "$source_checkout" ls-remote --exit-code --heads origin refs/heads/screenshots >/dev/null
remote_status=$?
set -e
case "$remote_status" in
    0)
        git -C "$source_checkout" fetch --no-tags --depth=1 origin refs/heads/screenshots
        git -C "$source_checkout" worktree add --detach "$publication" FETCH_HEAD
        ;;
    2)
        git -C "$source_checkout" worktree add --detach "$publication" HEAD
        git -C "$publication" switch --orphan screenshots
        ;;
    *) exit "$remote_status" ;;
esac

mkdir -p "$publication/android"
rsync -a --delete "$prepared/android/" "$publication/android/"
cp "$prepared/README.md" "$publication/README.md"
git -C "$publication" add -- android README.md
if git -C "$publication" diff --cached --quiet; then
    echo 'Published screenshots are already current.'
    exit 0
fi
git -C "$publication" \
    -c user.name='github-actions[bot]' \
    -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
    commit -m 'Update Android screenshot gallery'
git -C "$publication" push origin HEAD:refs/heads/screenshots
