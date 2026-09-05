#!/usr/bin/env python3
"""Parse Yamaha pre-installed expansion contents into Dart catalogs."""

from __future__ import annotations

import re
from pathlib import Path

SRC = Path(__file__).with_name("expansion_contents.txt")
OUT = Path(__file__).resolve().parents[1] / "lib" / "catalog" / "expansion.dart"

CATEGORIES = ("Latin America", "African", "Europe", "Oriental")
TYPE_RE = re.compile(
    r"(S\.Art!?|Live!SFX|MegaVoice|Sweet!?|Cool!?|Regular|Live!?|SFX)\s*$"
)
SKIP = {
    "category",
    "voice name",
    "voice number",
    "voice type",
    "msb lsb pc#",
    "(1–128)",
    "(1-128)",
    "style name",
    "bank name",
    "contents",
}


def dart_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace("'", "\\'")


def strip_style_prefix(name: str) -> str:
    return re.sub(r"^\d+[_ ]", "", name).strip()


def parse(text: str) -> tuple[list[dict], list[dict]]:
    voices: list[dict] = []
    styles: list[dict] = []
    section = ""
    category = "Expansion"
    seen_v: set[tuple] = set()
    seen_s: set[str] = set()

    for raw in text.splitlines():
        line = re.sub(r"\s+", " ", raw).strip()
        lower = line.lower()
        if "voice list /" in lower or (section == "" and "voice list" in lower and "psr" in lower):
            section = "voices"
            continue
        if "style list /" in lower:
            section = "styles"
            continue
        if "multi pad" in lower:
            section = "pads"
            continue
        if (
            not line
            or lower in SKIP
            or lower.startswith("psr-")
            or lower.startswith("yamaha")
            or "liste der" in lower
            or "liste des" in lower
            or "lista de" in lower
            or lower.startswith("category style")
            or "...." in line
        ):
            continue
        if section == "voices":
            cat = next((c for c in CATEGORIES if line.startswith(c + " ") or line == c), None)
            if cat:
                category = cat
                line = line[len(cat) :].strip()
                if not line:
                    continue
            match = TYPE_RE.search(line)
            if not match:
                continue
            voice_type = match.group(1).replace("Live!S FX", "Live!SFX")
            body = line[: match.start()].strip()
            tokens = body.split()
            nums: list[int] = []
            while tokens and tokens[-1].isdigit() and len(nums) < 3:
                nums.append(int(tokens.pop()))
            nums.reverse()
            name = " ".join(tokens).strip()
            if len(nums) != 3 or not name:
                continue
            msb, lsb, pc = nums
            key = (name.lower(), msb, lsb, pc)
            if key in seen_v:
                continue
            seen_v.add(key)
            voices.append(
                {
                    "name": name,
                    "category": category,
                    "type": voice_type,
                    "msb": msb,
                    "lsb": lsb,
                    "pc": pc,
                    "slot": len(voices),
                }
            )
        elif section == "styles":
            cat = next((c for c in CATEGORIES if line.startswith(c + " ") or line == c), None)
            if cat:
                category = cat
                line = line[len(cat) :].strip()
                if not line:
                    continue
            if re.match(r"^\d+[_\s]", line) or "_" in line or re.match(r"^[A-Za-z]", line):
                name = strip_style_prefix(line)
                if not name or name.lower() in SKIP or len(name) < 2:
                    continue
                key = f"{category}:{name.lower()}"
                if key in seen_s:
                    continue
                seen_s.add(key)
                styles.append({"name": name, "category": category, "index": len(styles)})
    return voices, styles


def main() -> None:
    voices, styles = parse(SRC.read_text(encoding="utf-8"))
    lines = [
        "// Generated from Yamaha PSR-SX900/SX700 Pre-installed Expansion Contents List.",
        "import 'sound_source.dart';",
        "import 'style.dart';",
        "import 'voice.dart';",
        "",
        "const sx700ExpansionVoices = <SxVoice>[",
    ]
    for v in voices:
        lines.append(
            "  SxVoice("
            f"name: '{dart_escape(v['name'])}', "
            f"category: '{dart_escape(v['category'])}', "
            f"type: '{dart_escape(v['type'])}', "
            f"msb: {v['msb']}, lsb: {v['lsb']}, pc: {v['pc']}, "
            f"slot: {v['slot']}, source: SoundSource.expansion),"
        )
    lines += ["];", "", "const sx700ExpansionStyles = <SxStyle>["]
    for s in styles:
        lines.append(
            "  SxStyle("
            f"index: {s['index']}, "
            f"name: '{dart_escape(s['name'])}', "
            f"category: '{dart_escape(s['category'])}', "
            f"msb: 0, lsb: 0, pc: {s['index'] + 1}, source: SoundSource.expansion),"
        )
    lines += ["];", ""]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"expansion voices={len(voices)} styles={len(styles)}")


if __name__ == "__main__":
    main()
