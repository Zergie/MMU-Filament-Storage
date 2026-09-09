"""Validate and export explicitly declared YAMMU STL targets through FusionHeadless v2."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile


BASE_MATERIAL = "ABS Plastic (Voron Black)"
ACCENT_MATERIAL = "ABS Plastic (Voron Red)"
RED = "\033[31m"
RESET = "\033[0m"

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "FusionAddons" / "FusionHeadless"))
from cli import fusion_cli


def write_if_changed(path: Path, content: bytes) -> None:
    """Publish a complete file atomically, retaining unchanged timestamps."""
    if path.exists() and path.read_bytes() == content:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        stream.write(content)
    try:
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def check_export_support(base_url: str) -> None:
    schema = fusion_cli.load_schema(base_url, refresh=True)
    command = fusion_cli.commands_from_openapi(schema).get("export")
    orient = next((option for option in command.options if option.wire_name == "orient"), None) if command else None
    if orient is None or orient.kind != "string":
        raise ValueError("The running FusionHeadless add-in does not support string-valued orient. "
                         "Install its requirements and restart the add-in in Fusion before exporting STLs.")


def export_stl(payload: dict, target: Path, base_url: str) -> None:
    fusion_cli.run(["export", "--base-url", base_url, "--data", json.dumps(payload),
                    "--timeout", "180", "--output", str(target)])


def build_records(records: dict, cache_dir: Path, stl_root: Path, base_url: str,
                  verify_server: bool = True) -> tuple[int, int]:
    if not isinstance(records, dict):
        raise ValueError("Printable manifest must be an object keyed by UUID.json")
    stl_root = stl_root.resolve()
    pending = []
    seen = set()
    # Validate the entire plan before replacing any published STL.
    for name, record in records.items():
        identity = record["id"]
        if not re.fullmatch(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}", identity) or name != identity + ".json":
            raise ValueError(f"Invalid manifest identifier: {name!r}")
        target = Path(record["path"]).resolve()
        if not target.is_relative_to(stl_root) or target.suffix.lower() != ".stl":
            raise ValueError(f"STL output must stay inside {stl_root}: {target}")
        if target in seen:
            raise ValueError(f"Multiple manifests target the same STL: {target}")
        seen.add(target)
        bodies = record["bodies"]
        if not isinstance(bodies, list) or not bodies or not all(isinstance(body, str) and body for body in bodies):
            raise ValueError(f"{name}: expected nonempty body names")
        if not isinstance(record["component_id"], str) or not record["component_id"]:
            raise ValueError(f"{name}: expected a component identifier")
        pending.append((identity, record, target))

    if verify_server:
        check_export_support(base_url)
    cache_dir.mkdir(parents=True, exist_ok=True)
    exported = restored = 0
    for identity, record, target in pending:
        cache = cache_dir / (identity + ".stl")
        stamp = cache_dir / (identity + ".export.json")
        # This contract version invalidates legacy un-oriented cache files.
        inputs = {"version": 1, "record": record, "orient": "Build Plate"}
        try:
            state = json.loads(stamp.read_text(encoding="utf-8"))
            content = cache.read_bytes()
            reusable = isinstance(state, dict) and state.get("inputs") == inputs and state.get("sha256") == hashlib.sha256(content).hexdigest()
        except (OSError, ValueError):
            reusable = False
        if not reusable:
            print(f"Exporting {record.get('component_name', record['component_id'])}: {', '.join(record['bodies'])}", flush=True)
            handle, filename = tempfile.mkstemp(suffix=".stl", dir=cache_dir)
            os.close(handle)
            temporary = Path(filename)
            try:
                export_stl({"format": "stl", "component": record["component_id"],
                            "body": record["bodies"], "orient": "Build Plate"}, temporary, base_url)
                content = temporary.read_bytes()
                if len(content) < 84 or int.from_bytes(content[80:84], "little") == 0 or len(content) != 84 + int.from_bytes(content[80:84], "little") * 50:
                    raise ValueError(f"{target}: export did not return a complete, nonempty binary STL")
                write_if_changed(cache, content)
                write_if_changed(stamp, (json.dumps({"inputs": inputs, "sha256": hashlib.sha256(content).hexdigest()}, indent=2) + "\n").encode())
                exported += 1
            finally:
                temporary.unlink(missing_ok=True)
        if not target.exists() or target.read_bytes() != content:
            write_if_changed(target, content)
            restored += 1
        # Retain manifests for inspection; stale entries never enter this plan.
        write_if_changed(cache_dir / (identity + ".json"), (json.dumps(record, indent=2) + "\n").encode())
    return exported, restored


def build(manifest: Path, cache_dir: Path, stl_root: Path, base_url: str) -> tuple[int, int]:
    records = json.loads(manifest.read_text(encoding="utf-8"))
    return build_records(records, cache_dir, stl_root, base_url)


def load_components(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, dict) and data.get("status") == "ok" and "result" in data:
        data = data["result"]
    if not isinstance(data, dict):
        raise ValueError("Components must be a JSON object keyed by component ID")
    return data


def select_record(components: dict, target: Path, body_names: list[str],
                  component_name: str | None = None,
                  base_material: str = BASE_MATERIAL,
                  accent_material: str = ACCENT_MATERIAL) -> dict:
    """Resolve a human-readable target declaration without inspecting its filename."""
    if not body_names or any(not name for name in body_names):
        raise ValueError(f"{target}: at least one body name is required")
    if len(set(body_names)) != len(body_names):
        raise ValueError(f"{target}: duplicate body selector")

    candidates = []
    for component in components.values():
        if not isinstance(component, dict) or not all(
            key in component for key in ("id", "name", "occurrences", "bodies")
        ):
            raise ValueError("Each component requires id, name, occurrences and bodies")
        if component_name is not None and component["name"] != component_name:
            continue
        for body in component["bodies"]:
            if body.get("name") in body_names and body.get("material") in (base_material, accent_material):
                candidates.append((component, body))

    selected = []
    for body_name in body_names:
        matches = [(component, body) for component, body in candidates if body["name"] == body_name]
        if not matches:
            qualifier = f" in component {component_name!r}" if component_name else ""
            raise ValueError(f"{target}: no printable body named {body_name!r}{qualifier}")
        if len(matches) > 1:
            names = ", ".join(sorted({component["name"] for component, _ in matches}))
            raise ValueError(
                f"{target}: body name {body_name!r} is not unique; matching components: {names}. "
                "Qualify it with the component name."
            )
        selected.append(matches[0])

    component = selected[0][0]
    if any(candidate["id"] != component["id"] for candidate, _ in selected[1:]):
        raise ValueError(f"{target}: grouped bodies must belong to one component")
    occurrences = component["occurrences"]
    if not isinstance(occurrences, list) or not occurrences:
        raise ValueError(f"{target}: component {component['name']!r} has no occurrences")
    materials = {body["material"] for _, body in selected}
    if len(materials) != 1:
        raise ValueError(f"{target}: grouped bodies must use the same print color")
    for _, body in selected:
        if not isinstance(body.get("hash"), str) or not body["hash"]:
            raise ValueError(f"{target}: body {body['name']!r} has no geometry hash")

    errors = []
    expected_count = len(occurrences)
    count_match = re.search(r"_x(\d+)$", target.stem)
    actual_count = int(count_match.group(1)) if count_match else 1
    if actual_count != expected_count or (expected_count == 1 and count_match):
        expected = "no _xN suffix" if expected_count == 1 else f"_x{expected_count}"
        actual = count_match.group(0) if count_match else "no suffix"
        errors.append(f"expected {expected}, found {actual}")

    is_accent = next(iter(materials)) == accent_material
    exact_accent = target.name.startswith("[a]_")
    contains_accent = "[a]" in target.name.lower()
    if is_accent and not exact_accent:
        errors.append("accent material requires the exact [a]_ filename prefix")
    if not is_accent and contains_accent:
        errors.append("base material must not contain the [a] color marker")
    if errors:
        raise ValueError(f"{target}: " + "; ".join(errors))

    path_text = str(target)
    identity = hashlib.md5(path_text.encode()).hexdigest()
    identity = f"{identity[:8]}-{identity[8:12]}-{identity[12:16]}-{identity[16:20]}-{identity[20:]}"
    return {
        "id": identity,
        "path": path_text,
        "bodies": [body["name"] for _, body in selected],
        "body_hashes": [body["hash"] for _, body in selected],
        "component_id": component["id"],
        "component_name": component["name"],
    }


def main(arguments: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--components", type=Path)
    parser.add_argument("--target", type=Path)
    parser.add_argument("--component")
    parser.add_argument("--body", action="append", dest="bodies")
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--cache-dir", type=Path, default=Path("obj/STLs"))
    parser.add_argument("--stl-root", type=Path, default=Path("STLs"))
    parser.add_argument("--base-url", default=fusion_cli.DEFAULT_BASE_URL)
    args = parser.parse_args(arguments)
    try:
        if args.manifest:
            if args.components or args.target or args.component or args.bodies or args.check_only:
                parser.error("--manifest cannot be combined with target selection options")
            exported, restored = build(args.manifest, args.cache_dir, args.stl_root, args.base_url)
        else:
            if not args.components or not args.target or not args.bodies:
                parser.error("target builds require --components, --target and at least one --body")
            record = select_record(
                load_components(args.components), args.target, args.bodies, args.component
            )
            if args.check_only:
                return 0
            records = {record["id"] + ".json": record}
            exported, restored = build_records(
                records, args.cache_dir, args.stl_root, args.base_url, verify_server=False
            )
        print(f"STLs: {exported} exported, {restored} published.")
        return 0
    except (OSError, ValueError, KeyError, TypeError, fusion_cli.CliError) as error:
        print(f"{RED}export_stl: {error}{RESET}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
