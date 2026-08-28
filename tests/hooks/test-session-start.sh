#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK_UNDER_TEST="$REPO_ROOT/hooks/session-start"
WRAPPER_UNDER_TEST="$REPO_ROOT/hooks/run-hook.cmd"

FAILURES=0
TEST_ROOT="$(mktemp -d)"

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

pass() {
    echo "  [PASS] $1"
}

fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

make_home() {
    local name="$1"
    local home="$TEST_ROOT/$name/home"
    mkdir -p "$home"
    printf '%s\n' "$home"
}

make_fake_curl_bin() {
    local bin="$TEST_ROOT/fake-curl-bin"
    mkdir -p "$bin"
    ln -s "$(node -p 'process.execPath')" "$bin/node"
    cat > "$bin/curl" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

count_file="${NELA_TEST_CURL_COUNT_FILE:-}"
if [[ -n "$count_file" ]]; then
    count=0
    if [[ -f "$count_file" ]]; then
        count="$(cat "$count_file")"
    fi
    printf '%s\n' "$((count + 1))" > "$count_file"
fi

max_time=""
while [[ "$#" -gt 0 ]]; do
    if [[ "$1" == "--max-time" && "$#" -gt 1 ]]; then
        max_time="$2"
        shift 2
        continue
    fi
    shift
done

if [[ -n "${NELA_TEST_CURL_MAX_TIME_FILE:-}" ]]; then
    printf '%s\n' "$max_time" > "$NELA_TEST_CURL_MAX_TIME_FILE"
fi

case "${NELA_TEST_CURL_MODE:-ok}" in
    ok)
        printf '%s' "${NELA_TEST_CURL_RESPONSE:-}"
        ;;
    fail)
        exit 22
        ;;
    timeout)
        exit 28
        ;;
    *)
        exit 2
        ;;
esac
SCRIPT
    chmod +x "$bin/curl"
    printf '%s\n' "$bin"
}

make_path_without_curl() {
    local bin="$TEST_ROOT/no-curl-bin"
    local command_name command_path
    mkdir -p "$bin"
    for command_name in bash cat dirname mkdir; do
        command_path="$(command -v "$command_name")"
        ln -s "$command_path" "$bin/$command_name"
    done
    ln -s "$(node -p 'process.execPath')" "$bin/node"
    printf '%s\n' "$bin"
}

assert_command_output() {
    local description="$1"
    local shape="$2"
    local contains="$3"
    local not_contains="$4"
    local home="$5"
    shift 5

    local output
    if ! output="$(env -i PATH="${PATH:-}" HOME="$home" "$@" 2>&1)"; then
        fail "$description"
        echo "    hook exited non-zero"
        echo "$output" | sed 's/^/      /'
        return
    fi

    if printf '%s' "$output" | \
        EXPECT_SHAPE="$shape" \
        EXPECT_CONTAINS="$contains" \
        EXPECT_NOT_CONTAINS="$not_contains" \
        node -e '
const fs = require("fs");

const input = fs.readFileSync(0, "utf8");
let payload;
try {
  payload = JSON.parse(input);
} catch (error) {
  console.error(`invalid JSON: ${error.message}`);
  process.exit(1);
}

function hasOwn(object, key) {
  return Object.prototype.hasOwnProperty.call(object, key);
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

const shape = process.env.EXPECT_SHAPE;
let context;

if (shape === "nested") {
  if (!hasOwn(payload, "hookSpecificOutput")) {
    fail("missing hookSpecificOutput");
  }
  if (hasOwn(payload, "additional_context") || hasOwn(payload, "additionalContext")) {
    fail("nested output also included a top-level context field");
  }
  const hookOutput = payload.hookSpecificOutput;
  if (!hookOutput || typeof hookOutput !== "object" || Array.isArray(hookOutput)) {
    fail("hookSpecificOutput is not an object");
  }
  if (hookOutput.hookEventName !== "SessionStart") {
    fail(`unexpected hookEventName: ${hookOutput.hookEventName}`);
  }
  context = hookOutput.additionalContext;
} else if (shape === "cursor") {
  if (hasOwn(payload, "hookSpecificOutput")) {
    fail("cursor output included hookSpecificOutput");
  }
  if (!hasOwn(payload, "additional_context")) {
    fail("cursor output missing additional_context");
  }
  if (hasOwn(payload, "additionalContext")) {
    fail("cursor output included additionalContext");
  }
  context = payload.additional_context;
} else if (shape === "sdk") {
  if (hasOwn(payload, "hookSpecificOutput")) {
    fail("sdk output included hookSpecificOutput");
  }
  if (!hasOwn(payload, "additionalContext")) {
    fail("sdk output missing additionalContext");
  }
  if (hasOwn(payload, "additional_context")) {
    fail("sdk output included additional_context");
  }
  context = payload.additionalContext;
} else {
  fail(`unknown expected shape: ${shape}`);
}

if (typeof context !== "string" || context.trim() === "") {
  fail("injected context was empty");
}

const expectedTexts = (process.env.EXPECT_CONTAINS || "")
  .split("\u001f")
  .filter(Boolean);
for (const expectedText of expectedTexts) {
  if (!context.includes(expectedText)) {
    fail(`context did not contain expected text: ${expectedText}`);
  }
}

const forbiddenTexts = (process.env.EXPECT_NOT_CONTAINS || "")
  .split("\u001f")
  .filter(Boolean);
for (const forbiddenText of forbiddenTexts) {
  if (context.includes(forbiddenText)) {
    fail(`context contained forbidden text: ${forbiddenText}`);
  }
}
'; then
        pass "$description"
    else
        fail "$description"
        echo "    output:"
        echo "$output" | sed 's/^/      /'
    fi
}

echo "SessionStart hook output tests"

# Registration shape: the hook must declare shell:"bash" so Claude Code on
# Windows dispatches via Git Bash (or fails with an actionable error) instead
# of PowerShell/cmd.exe, whose parsers break on the quoted command string
# (PowerShell ParserError; cmd.exe quote-stripping on paths with metacharacters).
if node -e '
const hooks = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const entry = hooks.hooks.SessionStart[0].hooks[0];
if (entry.shell !== "bash") {
  console.error(`SessionStart hook shell is ${JSON.stringify(entry.shell)}, expected "bash"`);
  process.exit(1);
}
if (!/run-hook\.cmd" session-start$/.test(entry.command)) {
  console.error(`unexpected SessionStart command shape: ${entry.command}`);
  process.exit(1);
}
' "$REPO_ROOT/hooks/hooks.json"; then
    pass "hooks.json registers SessionStart with shell:bash dispatch"
else
    fail "hooks.json registers SessionStart with shell:bash dispatch"
fi

claude_home="$(make_home claude-code)"
assert_command_output \
    "Claude Code emits nested SessionStart additionalContext" \
    "nested" \
    "" \
    "" \
    "$claude_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

wrapper_home="$(make_home run-hook-wrapper)"
assert_command_output \
    "run-hook.cmd wrapper dispatches to the named session-start script" \
    "nested" \
    "" \
    "" \
    "$wrapper_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$WRAPPER_UNDER_TEST" session-start

cursor_home="$(make_home cursor)"
assert_command_output \
    "Cursor emits top-level additional_context only" \
    "cursor" \
    "" \
    "" \
    "$cursor_home" \
    CURSOR_PLUGIN_ROOT="$REPO_ROOT" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

copilot_home="$(make_home copilot-cli)"
assert_command_output \
    "Copilot CLI emits top-level additionalContext only" \
    "sdk" \
    "" \
    "" \
    "$copilot_home" \
    COPILOT_CLI=1 \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

legacy_home="$(make_home legacy-warning-removed)"
mkdir -p "$legacy_home/.config/superpowers/skills"
assert_command_output \
    "SessionStart omits obsolete legacy custom-skill warning" \
    "nested" \
    "" \
    "Superpowers now uses"$'\037'"~/.config/superpowers/skills"$'\037'"~/.claude/skills"$'\037'"legacy" \
    "$legacy_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

echo "Nela fork release reminder tests"

fake_curl_bin="$(make_fake_curl_bin)"
reminder_fragment="tested Nela fork release"
installed_version="$(node -p 'require(process.argv[1]).version' "$REPO_ROOT/.claude-plugin/plugin.json")"
newer_version="$(node -e '
const match = /^(\d+\.\d+\.\d+-nela\.)(\d+)$/.exec(process.argv[1]);
if (!match) process.exit(1);
process.stdout.write(`${match[1]}${Number(match[2]) + 1}`);
' "$installed_version")"
older_version="$(node -e '
const match = /^(\d+\.\d+\.\d+-nela\.)(\d+)$/.exec(process.argv[1]);
if (!match || Number(match[2]) === 0) process.exit(1);
process.stdout.write(`${match[1]}${Number(match[2]) - 1}`);
' "$installed_version")"
newer_manifest="$(printf '{\"name\":\"superpowers\",\"version\":\"%s\"}' "$newer_version")"
equal_manifest="$(printf '{\"name\":\"superpowers\",\"version\":\"%s\"}' "$installed_version")"
older_manifest="$(printf '{\"name\":\"superpowers\",\"version\":\"%s\"}' "$older_version")"
reminder_home="$(make_home newer-tested-release)"
curl_count="$TEST_ROOT/newer-tested-release-curl-count"

assert_command_output \
    "newer tested fork release adds a passive Claude deployment reminder" \
    "nested" \
    "$reminder_fragment"$'\037'"not automatic"$'\037'"NELA.md" \
    "" \
    "$reminder_home" \
    PATH="$fake_curl_bin:$PATH" \
    NELA_TEST_CURL_RESPONSE="$newer_manifest" \
    NELA_TEST_CURL_COUNT_FILE="$curl_count" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

assert_command_output \
    "same unresolved release is suppressed during the seven-day reminder window" \
    "nested" \
    "" \
    "$reminder_fragment" \
    "$reminder_home" \
    PATH="$fake_curl_bin:$PATH" \
    NELA_TEST_CURL_RESPONSE="$newer_manifest" \
    NELA_TEST_CURL_COUNT_FILE="$curl_count" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

cache_file="$reminder_home/.cache/nela-superpowers/claude-fork-version.json"
node -e '
const fs = require("fs");
const file = process.argv[1];
const cache = JSON.parse(fs.readFileSync(file, "utf8"));
cache.remindedAt = Math.floor(Date.now() / 1000) - (8 * 24 * 60 * 60);
fs.writeFileSync(file, `${JSON.stringify(cache)}\n`);
' "$cache_file"
touch "$cache_file"

assert_command_output \
    "unresolved release reminder reappears after seven days" \
    "nested" \
    "$reminder_fragment" \
    "" \
    "$reminder_home" \
    PATH="$fake_curl_bin:$PATH" \
    NELA_TEST_CURL_RESPONSE="$newer_manifest" \
    NELA_TEST_CURL_COUNT_FILE="$curl_count" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

if [[ "$(cat "$curl_count")" == "1" ]]; then
    pass "tested-main version is fetched once and reused from the 24-hour cache"
else
    fail "tested-main version is fetched once and reused from the 24-hour cache"
fi

equal_home="$(make_home equal-tested-release)"
assert_command_output \
    "equal installed and tested-main versions are quiet" \
    "nested" \
    "" \
    "$reminder_fragment" \
    "$equal_home" \
    PATH="$fake_curl_bin:$PATH" \
    NELA_TEST_CURL_RESPONSE="$equal_manifest" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

newer_installed_home="$(make_home installed-newer-than-main)"
assert_command_output \
    "installed fork version newer than tested main is quiet" \
    "nested" \
    "" \
    "$reminder_fragment" \
    "$newer_installed_home" \
    PATH="$fake_curl_bin:$PATH" \
    NELA_TEST_CURL_RESPONSE="$older_manifest" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

malformed_home="$(make_home malformed-tested-main)"
assert_command_output \
    "malformed tested-main JSON leaves valid quiet SessionStart output" \
    "nested" \
    "" \
    "$reminder_fragment" \
    "$malformed_home" \
    PATH="$fake_curl_bin:$PATH" \
    NELA_TEST_CURL_RESPONSE='{' \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

failed_home="$(make_home failed-tested-main-read)"
assert_command_output \
    "failed tested-main read leaves valid quiet SessionStart output" \
    "nested" \
    "" \
    "$reminder_fragment" \
    "$failed_home" \
    PATH="$fake_curl_bin:$PATH" \
    NELA_TEST_CURL_MODE=fail \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

timeout_home="$(make_home timed-out-tested-main-read)"
max_time_file="$TEST_ROOT/curl-max-time"
assert_command_output \
    "timed-out tested-main read leaves valid quiet SessionStart output" \
    "nested" \
    "" \
    "$reminder_fragment" \
    "$timeout_home" \
    PATH="$fake_curl_bin:$PATH" \
    NELA_TEST_CURL_MODE=timeout \
    NELA_TEST_CURL_MAX_TIME_FILE="$max_time_file" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"
if [[ -f "$max_time_file" && "$(cat "$max_time_file")" == "2" ]]; then
    pass "tested-main remote read is capped at two seconds"
else
    fail "tested-main remote read is capped at two seconds"
fi

no_curl_home="$(make_home curl-unavailable)"
no_curl_path="$(make_path_without_curl)"
assert_command_output \
    "missing curl leaves valid quiet SessionStart output" \
    "nested" \
    "" \
    "$reminder_fragment" \
    "$no_curl_home" \
    PATH="$no_curl_path" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

unwritable_home="$TEST_ROOT/unwritable-home"
touch "$unwritable_home"
assert_command_output \
    "unavailable cache directory leaves valid quiet SessionStart output" \
    "nested" \
    "" \
    "$reminder_fragment" \
    "$unwritable_home" \
    PATH="$fake_curl_bin:$PATH" \
    NELA_TEST_CURL_RESPONSE="$newer_manifest" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

cursor_reminder_home="$(make_home cursor-reminder-scope)"
assert_command_output \
    "cursor output receives no work-Mac deployment reminder" \
    "cursor" \
    "" \
    "$reminder_fragment" \
    "$cursor_reminder_home" \
    PATH="$fake_curl_bin:$PATH" \
    NELA_TEST_CURL_RESPONSE="$newer_manifest" \
    CURSOR_PLUGIN_ROOT="$REPO_ROOT" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

copilot_reminder_home="$(make_home copilot-reminder-scope)"
assert_command_output \
    "copilot output receives no work-Mac deployment reminder" \
    "sdk" \
    "" \
    "$reminder_fragment" \
    "$copilot_reminder_home" \
    PATH="$fake_curl_bin:$PATH" \
    NELA_TEST_CURL_RESPONSE="$newer_manifest" \
    COPILOT_CLI=1 \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

unknown_reminder_home="$(make_home unknown-reminder-scope)"
assert_command_output \
    "unknown-platform output receives no work-Mac deployment reminder" \
    "sdk" \
    "" \
    "$reminder_fragment" \
    "$unknown_reminder_home" \
    PATH="$fake_curl_bin:$PATH" \
    NELA_TEST_CURL_RESPONSE="$newer_manifest" \
    bash "$HOOK_UNDER_TEST"

if [[ "$FAILURES" -gt 0 ]]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi

echo "STATUS: PASSED"
