#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

python3 - "$REPO_ROOT" <<'PY'
import json
import re
import subprocess
import sys
from pathlib import Path

repo = Path(sys.argv[1])
errors: list[str] = []


def load_json(relative_path: str):
    path = repo / relative_path
    if not path.is_file():
        errors.append(f"missing {relative_path}")
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        errors.append(f"invalid {relative_path}: {error}")
        return None


def read_json_field(data, field: str):
    value = data
    for component in field.split("."):
        if component.isdigit():
            value = value[int(component)]
        else:
            value = value[component]
    return value


expected_upstream = {
    "repository": "https://github.com/obra/superpowers.git",
    "tag": "v6.3.0",
    "commit": "b36e0829c6d0140e93cfef2ca599b1b07d4a7797",
}
upstream = load_json("UPSTREAM.json")
if upstream is not None:
    if upstream != expected_upstream:
        errors.append(f"UPSTREAM.json does not match the accepted base: {upstream!r}")
    else:
        resolved = subprocess.run(
            ["git", "-C", str(repo), "rev-parse", f"refs/tags/{upstream['tag']}^{{}}"],
            check=False,
            capture_output=True,
            text=True,
        )
        if resolved.returncode != 0:
            errors.append(f"cannot resolve accepted upstream tag {upstream['tag']}")
        elif resolved.stdout.strip() != upstream["commit"]:
            errors.append(
                f"accepted tag resolves to {resolved.stdout.strip()}, expected {upstream['commit']}"
            )

for marketplace_path in (
    ".agents/plugins/marketplace.json",
    ".claude-plugin/marketplace.json",
):
    marketplace = load_json(marketplace_path)
    if marketplace is None:
        continue
    if marketplace.get("name") != "nela-superpowers":
        errors.append(
            f"{marketplace_path} name is {marketplace.get('name')!r}, expected 'nela-superpowers'"
        )
    plugins = marketplace.get("plugins")
    if not isinstance(plugins, list):
        errors.append(f"{marketplace_path} plugins is not a list")
    elif [plugin.get("name") for plugin in plugins].count("superpowers") != 1:
        errors.append(f"{marketplace_path} must contain exactly one superpowers plugin")

codex_marketplace = load_json(".agents/plugins/marketplace.json")
if codex_marketplace is not None:
    display_name = codex_marketplace.get("interface", {}).get("displayName")
    if display_name != "Nela Superpowers":
        errors.append(
            f"Codex marketplace display name is {display_name!r}, expected 'Nela Superpowers'"
        )

for manifest_path in (
    ".codex-plugin/plugin.json",
    ".claude-plugin/plugin.json",
):
    manifest = load_json(manifest_path)
    if manifest is None:
        continue
    for field in ("homepage", "repository"):
        if manifest.get(field) != "https://github.com/nht007/superpowers":
            errors.append(
                f"{manifest_path} {field} is {manifest.get(field)!r}, expected the Nela fork"
            )

version_registry = load_json(".version-bump.json")
observed_versions: dict[str, str] = {}
if version_registry is not None:
    for entry in version_registry.get("files", []):
        relative_path = entry.get("path")
        field = entry.get("field")
        if not isinstance(relative_path, str) or not isinstance(field, str):
            errors.append(f"invalid version registry entry: {entry!r}")
            continue
        path = repo / relative_path
        if not path.is_file():
            errors.append(f"version registry path is missing: {relative_path}")
            continue
        try:
            if path.suffix == ".json":
                data = json.loads(path.read_text(encoding="utf-8"))
                value = read_json_field(data, field)
            elif path.suffix == ".yaml":
                result = subprocess.run(
                    ["yq", "-er", f".{field}", str(path)],
                    check=False,
                    capture_output=True,
                    text=True,
                )
                if result.returncode != 0:
                    raise ValueError(result.stderr.strip() or "yq failed")
                value = result.stdout.strip()
            else:
                raise ValueError(f"unsupported manifest type: {path.suffix}")
        except (IndexError, KeyError, OSError, TypeError, ValueError, json.JSONDecodeError) as error:
            errors.append(f"cannot read {relative_path} field {field}: {error}")
            continue
        observed_versions[f"{relative_path}:{field}"] = str(value)

expected_version = observed_versions.get(".codex-plugin/plugin.json:version")
if expected_version is None:
    errors.append("version registry does not define .codex-plugin/plugin.json:version")
else:
    for location, version in observed_versions.items():
        if version != expected_version:
            errors.append(f"{location} is {version!r}, expected {expected_version!r}")

    match = re.fullmatch(r"(\d+\.\d+\.\d+)-nela\.(\d+)", expected_version)
    if match is None:
        errors.append(
            "Codex plugin version is not an upstream-derived Nela version: "
            f"{expected_version!r}"
        )
    elif int(match.group(2)) < 1:
        errors.append(f"Codex plugin Nela revision must be at least 1: {expected_version!r}")
    elif upstream is not None and upstream.get("tag") != f"v{match.group(1)}":
        errors.append(
            f"fork version base v{match.group(1)} does not match {upstream.get('tag')!r}"
        )

nela_path = repo / "NELA.md"
if not nela_path.is_file():
    errors.append("missing NELA.md")
else:
    nela_text = nela_path.read_text(encoding="utf-8")
    for required in (
        "nht007/superpowers",
        expected_upstream["tag"],
        expected_upstream["commit"],
    ):
        if required not in nela_text:
            errors.append(f"NELA.md does not name {required}")

if errors:
    print("Nela fork contract failed:", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    raise SystemExit(1)

print("Nela fork contract looks good")
PY
