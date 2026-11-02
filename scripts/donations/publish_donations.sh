#!/usr/bin/env bash
set -euo pipefail

prepared="${1:?Usage: publish_donations.sh TOTALS_JSON SOURCE_CHECKOUT WORKTREE}"
source_checkout="${2:?Authenticated source checkout is required.}"
publication="${3:?A new worktree path is required.}"

# Only yearly currency totals may ever enter the public data branch.
python3 - "$prepared" <<'PY'
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    totals = json.load(source)
assert isinstance(totals, dict) and totals, "No yearly totals to publish"
for year, currencies in totals.items():
    assert re.fullmatch(r"20[0-9]{2}", year), "Unexpected year key"
    assert isinstance(currencies, dict), "Expected currency totals"
    for currency, amount in currencies.items():
        assert re.fullmatch(r"[A-Z]{3}", currency), "Unexpected currency key"
        assert isinstance(amount, str) and re.fullmatch(r"-?[0-9]+(?:\.[0-9]+)?", amount), "Invalid amount"
PY

set +e
git -C "$source_checkout" ls-remote --exit-code --heads origin refs/heads/donation-data >/dev/null
remote_status=$?
set -e
case "$remote_status" in
    0)
        git -C "$source_checkout" fetch --no-tags --depth=1 origin refs/heads/donation-data
        git -C "$source_checkout" worktree add --detach "$publication" FETCH_HEAD
        ;;
    2)
        git -C "$source_checkout" worktree add --detach "$publication" HEAD
        git -C "$publication" switch --orphan donation-data
        ;;
    *) exit "$remote_status" ;;
esac

# Refuse to publish into a branch which contains anything besides our output.
unexpected="$(git -C "$publication" ls-files | sed '/^donations\.json$/d')"
[[ -z "$unexpected" ]] || { echo 'Unexpected files on donation-data; publication stopped.' >&2; exit 1; }
cp "$prepared" "$publication/donations.json"
git -C "$publication" add -- donations.json
if git -C "$publication" diff --cached --quiet; then
    echo 'Published donation totals are already current.'
    exit 0
fi
git -C "$publication" \
    -c user.name='github-actions[bot]' \
    -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
    commit -m 'Update yearly donation totals'
git -C "$publication" push origin HEAD:refs/heads/donation-data
