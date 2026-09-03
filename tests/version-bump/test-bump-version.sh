#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_SOURCE="$REPO_ROOT/scripts/bump-version.sh"
TEST_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

make_fixture() {
  local repo="$1"
  local yaml_body="$2"

  mkdir -p "$repo/scripts" "$repo/.hermes-plugin"
  cp "$SCRIPT_SOURCE" "$repo/scripts/bump-version.sh"
  cat >"$repo/.version-bump.json" <<'JSON'
{
  "files": [
    { "path": "package.json", "field": "version" },
    { "path": ".hermes-plugin/plugin.yaml", "field": "version" }
  ],
  "audit": { "exclude": [] }
}
JSON
  cat >"$repo/package.json" <<'JSON'
{
  "name": "fixture",
  "version": "1.2.3"
}
JSON
  printf '%s\n' "$yaml_body" >"$repo/.hermes-plugin/plugin.yaml"
}

happy_repo="$TEST_ROOT/happy"
make_fixture "$happy_repo" $'name: superpowers\nversion: 1.2.3'
mkdir -p "$happy_repo/.worktrees/linked-checkout"
cp "$happy_repo/package.json" "$happy_repo/.worktrees/linked-checkout/package.json"

/bin/bash "$happy_repo/scripts/bump-version.sh" --check >"$TEST_ROOT/check.out"
/bin/bash "$happy_repo/scripts/bump-version.sh" --audit >"$TEST_ROOT/audit.out"
/bin/bash "$happy_repo/scripts/bump-version.sh" 2.3.4 >"$TEST_ROOT/bump.out"

if grep -q '.worktrees/linked-checkout/package.json' "$TEST_ROOT/audit.out"; then
  fail "audit scanned a nested worktree"
fi

[[ "$(jq -r '.version' "$happy_repo/package.json")" == "2.3.4" ]] \
  || fail "JSON manifest was not bumped"
[[ "$(yq -r '.version' "$happy_repo/.hermes-plugin/plugin.yaml")" == "2.3.4" ]] \
  || fail "YAML manifest was not bumped"

jq -e '
  any(.files[];
    .path == ".hermes-plugin/plugin.yaml" and .field == "version")
' "$REPO_ROOT/.version-bump.json" >/dev/null \
  || fail "Hermes manifest is not registered"

undeclared_repo="$TEST_ROOT/undeclared"
make_fixture "$undeclared_repo" $'name: superpowers\nversion: 1.2.3'
printf '%s\n' '{ "version": "1.2.3" }' >"$undeclared_repo/unregistered.json"

if /bin/bash "$undeclared_repo/scripts/bump-version.sh" --audit \
  >"$TEST_ROOT/undeclared.out" 2>&1; then
  fail "audit accepted an undeclared version reference"
fi

grep -q 'unregistered.json' "$TEST_ROOT/undeclared.out" \
  || fail "audit did not report the undeclared file"

drift_repo="$TEST_ROOT/drift"
make_fixture "$drift_repo" $'name: superpowers\nversion: 1.2.3'
cat >"$drift_repo/package.json" <<'JSON'
{
  "name": "fixture",
  "version": "4.5.6"
}
JSON
printf '%s\n' '{ "versions": ["1.2.3", "4.5.6"] }' \
  >"$drift_repo/drift-unregistered.json"

if /bin/bash "$drift_repo/scripts/bump-version.sh" --audit \
  >"$TEST_ROOT/drift.out" 2>&1; then
  fail "audit accepted declared version drift"
fi

grep -q 'DRIFT DETECTED' "$TEST_ROOT/drift.out" \
  || fail "audit did not report declared version drift"
grep -q 'drift-unregistered.json' "$TEST_ROOT/drift.out" \
  || fail "audit stopped before reporting undeclared files"

invalid_repo="$TEST_ROOT/invalid"
make_fixture "$invalid_repo" $'name: superpowers\nversion: 123'
cp "$invalid_repo/package.json" "$TEST_ROOT/package.before"
cp "$invalid_repo/.hermes-plugin/plugin.yaml" "$TEST_ROOT/plugin.before"

if /bin/bash "$invalid_repo/scripts/bump-version.sh" 2.3.4 \
  >"$TEST_ROOT/invalid.out" 2>&1; then
  fail "bump accepted a non-string YAML version"
fi

cmp -s "$TEST_ROOT/package.before" "$invalid_repo/package.json" \
  || fail "JSON manifest changed before YAML validation failed"
cmp -s "$TEST_ROOT/plugin.before" "$invalid_repo/.hermes-plugin/plugin.yaml" \
  || fail "invalid YAML manifest changed"

echo "Version-bump tests passed"
