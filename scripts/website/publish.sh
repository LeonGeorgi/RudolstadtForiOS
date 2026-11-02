#!/usr/bin/env bash
# Publish only generated public files to Cloudflare's dedicated production branch.
set -euo pipefail

prepared="${1:?Usage: publish.sh PREPARED SOURCE_CHECKOUT NEW_WORKTREE}"
source_checkout="${2:?An authenticated source checkout is required.}"
publication="${3:?A new worktree path is required.}"
prepared="$(cd "$prepared" && pwd)"
source_checkout="$(cd "$source_checkout" && pwd)"
branch=website-deploy

for file in rudolstadt/index.html _headers .well-known/assetlinks.json .well-known/apple-app-site-association; do
    [[ -f "$prepared/$file" ]] || { printf 'Incomplete website: missing %s\n' "$file" >&2; exit 1; }
done
[[ ! -e "$publication" ]] || { printf 'Publication worktree must not already exist.\n' >&2; exit 1; }

set +e
git -C "$source_checkout" ls-remote --exit-code --heads origin "refs/heads/$branch" >/dev/null
remote_status=$?
set -e
case "$remote_status" in
    0)
        git -C "$source_checkout" fetch --no-tags --depth=1 origin "refs/heads/$branch"
        git -C "$source_checkout" worktree add --detach "$publication" FETCH_HEAD
        ;;
    2)
        git -C "$source_checkout" worktree add --detach "$publication" HEAD
        git -C "$publication" switch --orphan "$branch"
        ;;
    *) exit "$remote_status" ;;
esac

# This branch is owned by the generator; do not repurpose an existing app branch.
while IFS= read -r -d '' file; do
    case "$file" in
        website/*|wrangler.jsonc) ;;
        *) printf 'Unexpected file on deployment branch: %s\n' "$file" >&2; exit 1 ;;
    esac
done < <(git -C "$publication" ls-files -z)

mkdir -p "$publication/website"
rsync -a --delete "$prepared/" "$publication/website/"
python3 - "$source_checkout/wrangler.jsonc" "$publication/wrangler.jsonc" <<'PY'
import json
from pathlib import Path
import sys

# The source config currently uses plain JSON. Keep Worker/domain settings while
# removing all build hooks: Cloudflare receives only pre-generated static assets.
config = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
config.pop("build", None)
config["assets"]["directory"] = "./website"
Path(sys.argv[2]).write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
PY

git -C "$publication" add -- website wrangler.jsonc
if git -C "$publication" diff --cached --quiet; then
    printf 'Generated website is unchanged; no Cloudflare deployment needed.\n'
    exit 0
fi
source_commit="$(git -C "$source_checkout" rev-parse HEAD)"
git -C "$publication" \
    -c user.name='github-actions[bot]' \
    -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
    commit --quiet -m 'Update generated website' -m "Source: $source_commit"
git -C "$publication" push origin "HEAD:refs/heads/$branch"
