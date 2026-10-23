#!/usr/bin/env python3
"""Builds Safari content blocker rules for reguard from the lists in filters.json.

    python3 build.py converter   # clone and build AdGuard's ConverterTool into ./converter
    python3 build.py rules       # download the lists and write ./dist

dist/ gets one raw-DEFLATE file per blocker and Safari version, plus manifest.json describing them.
The build fails instead of publishing anything suspicious: a list that didn't download, a blocker
with too few rules, or more rules than Safari accepts.
"""

import datetime
import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile
import urllib.request
import zlib

ROOT = pathlib.Path(__file__).resolve().parent
CONFIG = json.loads((ROOT / "filters.json").read_text())
CONVERTER_DIR = ROOT / "converter"
CONVERTER_SOURCE = CONVERTER_DIR / "src"
CONVERTER_BINARY = CONVERTER_SOURCE / ".build" / "release" / "ConverterTool"
DIST = ROOT / "dist"

SAFARI_RULE_LIMIT = 150000


def build_converter():
    tag = CONFIG["converter"]["tag"]
    if CONVERTER_BINARY.exists():
        print(f"ConverterTool {tag} already built")
        return
    CONVERTER_DIR.mkdir(exist_ok=True)
    subprocess.run(["git", "clone", "--quiet", "--depth", "1", "--branch", tag,
                    CONFIG["converter"]["repository"], str(CONVERTER_SOURCE)], check=True)
    subprocess.run(["swift", "build", "-c", "release", "--product", "ConverterTool",
                    "--package-path", str(CONVERTER_SOURCE)], check=True)


def download(url):
    request = urllib.request.Request(url, headers={"User-Agent": "reguard-filters"})
    with urllib.request.urlopen(request, timeout=60) as response:
        text = response.read().decode("utf-8")
    header = {}
    for line in text.splitlines()[:30]:
        if line.startswith("! ") and ":" in line:
            key, value = line[2:].split(":", 1)
            header[key.strip()] = value.strip()
    if "Title" not in header or len(text) < 10000:
        raise SystemExit(f"{url} does not look like a filter list")
    return text, header


def convert(rules_path, safari_version, output_path):
    subprocess.run([str(CONVERTER_BINARY), "convert", "--safari-version", safari_version,
                    "--input-path", str(rules_path), "--safari-rules-json-path", str(output_path)],
                   check=True, stdout=subprocess.DEVNULL)
    return output_path.read_bytes()


def validate(blocker, safari_version, data, min_rules):
    rules = json.loads(data)
    if not isinstance(rules, list) or not all("trigger" in rule and "action" in rule for rule in rules):
        raise SystemExit(f"{blocker} for Safari {safari_version}: not a content blocker rule list")
    if not min_rules <= len(rules) <= SAFARI_RULE_LIMIT:
        raise SystemExit(f"{blocker} for Safari {safari_version}: {len(rules)} rules is outside {min_rules}..{SAFARI_RULE_LIMIT}")
    return len(rules)


def deflate(data):
    # Raw DEFLATE, which Apple's Compression framework reads as COMPRESSION_ZLIB.
    compressor = zlib.compressobj(9, zlib.DEFLATED, -15)
    return compressor.compress(data) + compressor.flush()


def build_rules():
    if not CONVERTER_BINARY.exists():
        raise SystemExit("Run `python3 build.py converter` first")
    DIST.mkdir(exist_ok=True)
    for old in DIST.iterdir():
        old.unlink()

    manifest = {
        "schema": 1,
        "generatedAt": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
        "converter": CONFIG["converter"]["tag"],
        "lists": [],
        "files": []
    }

    with tempfile.TemporaryDirectory() as work:
        work = pathlib.Path(work)
        for blocker, settings in CONFIG["blockers"].items():
            texts = []
            for entry in settings["lists"]:
                text, header = download(entry["url"])
                texts.append(text)
                manifest["lists"].append({
                    "blocker": blocker,
                    "id": entry["id"],
                    "title": entry["title"],
                    "version": header.get("Version"),
                    "updated": header.get("TimeUpdated")
                })
            rules_path = work / f"{blocker}.txt"
            rules_path.write_text("\n".join(texts) + "\n")

            for safari_version in CONFIG["safariVersions"]:
                data = convert(rules_path, safari_version, work / f"{blocker}-{safari_version}.json")
                count = validate(blocker, safari_version, data, settings["minRules"])
                name = f"{blocker}-{safari_version}.json.deflate"
                packed = deflate(data)
                (DIST / name).write_bytes(packed)
                manifest["files"].append({
                    "blocker": blocker,
                    "safari": safari_version,
                    "name": name,
                    "rules": count,
                    "sha256": hashlib.sha256(data).hexdigest(),
                    "bytes": len(packed)
                })
                print(f"{name}: {count} rules, {len(packed) / 1e6:.2f} MB")

    (DIST / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    commands = {"converter": build_converter, "rules": build_rules}
    if len(sys.argv) != 2 or sys.argv[1] not in commands:
        raise SystemExit(__doc__)
    commands[sys.argv[1]]()
