#!/usr/bin/env python3
"""Parse the Yamaha PSR-SX900/SX700 Data List text dump into Dart catalogs."""

from __future__ import annotations

import re
from pathlib import Path

DUMP = Path(
    "/Users/reyzie29/.cursor/projects/Users-reyzie29-Documents-Personal-Projects-SX700/agent-tools/2a8c4e90-5286-4d0e-bd10-c25119758635.txt"
)
OUT_DIR = Path(__file__).resolve().parents[1] / "lib" / "catalog"

TYPE_RE = re.compile(
    r"(S\.Art!?|Cool!?|Regular|Live!?Drums|Live!?S\s*FX|Live!?SFX|Live!?|"
    r"Sweet!?|MegaVoice|OrganFlutes|Drums|SFX)\s*$",
    re.I,
)
SKIP_HEADINGS = {
    "category",
    "sub",
    "voice name",
    "voice number",
    "voice type",
    "msb#",
    "lsb#",
    "pc#",
    "(1–128)",
    "(1-128)",
    "contents",
}

PREFERRED_MSB = {0, 8, 63, 64, 104, 120, 121, 122, 126, 127}


def normalize_name(raw: str) -> str:
    s = re.sub(r"\s+", " ", raw).strip()
    s = s.replace("T remolo", "Tremolo").replace("T rem", "Trem")
    s = s.replace("G u i t a r H e r o", "GuitarHero")
    s = s.replace("V odoo", "Voodoo")
    s = s.replace("W ah", "Wah").replace("W arm", "Warm")
    s = s.replace("MegaV oice", "").replace("MegaVo ice", "")
    s = re.sub(r"\s+", " ", s).strip(" -")
    return s


def parse_msb_lsb_pc(digits: str) -> tuple[int, int, int] | None:
    candidates: list[tuple[int, int, int, int]] = []
    n = len(digits)
    if n < 3:
        return None
    for i in range(1, min(4, n - 1)):
        for j in range(i + 1, min(i + 4, n)):
            a, b, c = digits[:i], digits[i:j], digits[j:]
            if not c or len(c) > 3:
                continue
            try:
                msb, lsb, pc = int(a), int(b), int(c)
            except ValueError:
                continue
            if not (0 <= msb <= 127 and 0 <= lsb <= 127 and 1 <= pc <= 128):
                continue
            score = 0
            if msb in PREFERRED_MSB:
                score += 6
            if msb == 104 and lsb <= 20:
                score += 3
            if msb == 0 and lsb >= 100:
                score += 3
            if msb in {126, 127}:
                score += 2
            score += len(b)  # prefer a fuller LSB field (122 vs 12)
            candidates.append((score, msb, lsb, pc))
    if not candidates:
        return None
    candidates.sort(key=lambda x: (x[0], x[2]), reverse=True)
    _, msb, lsb, pc = candidates[0]
    return msb, lsb, pc


def parse_voices(text: str) -> list[dict]:
    voices: list[dict] = []
    seen: set[tuple[str, int, int, int]] = set()
    category = "Piano"
    stop_markers = (
        "mega voice map",
        "drum/sfx kit list",
        "style list",
        "midi data format",
        "midi implementation",
    )
    in_voices = False
    for raw_line in text.splitlines():
        line = raw_line.strip()
        lower = line.lower()
        if "voice list" in lower and "psr" in lower:
            in_voices = True
        if not in_voices and lower.startswith("piano"):
            in_voices = True
        if any(m in lower for m in stop_markers) and in_voices and len(voices) > 40:
            # Keep going through SX700-specific repeats; only stop on MIDI chapter.
            if "midi data format" in lower or "midi implementation" in lower:
                break
        if not line or lower in SKIP_HEADINGS:
            continue
        if lower.startswith("psr-sx") or lower.startswith("yamaha"):
            continue
        if re.fullmatch(r"\d+", line):
            continue

        type_match = TYPE_RE.search(line.replace("MegaV oice", "MegaVoice").replace("MegaVo ice", "MegaVoice"))
        if not type_match:
            # Category headings like "Piano&E.Piano - ConcertGrand ..." already include a type.
            if " - " in line and not type_match:
                cat = line.split(" - ")[0].strip()
                if 2 < len(cat) < 40 and not any(ch.isdigit() for ch in cat[:3]):
                    category = cat.replace("&", " & ")
            continue

        voice_type = re.sub(r"\s+", "", type_match.group(1))
        body = line[: type_match.start()].strip()
        # Split trailing integers (may be OCR-split: "10 4 1 2 8")
        tokens = body.split()
        num_tokens: list[str] = []
        name_tokens: list[str] = []
        for tok in reversed(tokens):
            if re.fullmatch(r"\d{1,3}", tok):
                num_tokens.append(tok)
            else:
                break
        num_tokens.reverse()
        name_tokens = tokens[: len(tokens) - len(num_tokens)]
        if len(name_tokens) >= 2 and name_tokens[-1] in {"JS", "SW"}:
            pass
        name = normalize_name(" ".join(name_tokens))
        if " - " in name:
            cat, rest = name.split(" - ", 1)
            if len(cat) < 32:
                category = cat.replace("&", " & ")
                name = rest
        if not name or len(name) < 2:
            continue
        digits = "".join(num_tokens)
        parsed = parse_msb_lsb_pc(digits)
        if not parsed:
            continue
        msb, lsb, pc = parsed
        key = (name.lower(), msb, lsb, pc)
        if key in seen:
            continue
        seen.add(key)
        voices.append(
            {
                "name": name,
                "category": category,
                "type": voice_type.replace("Live!SFX", "Live!SFX")
                .replace("Live!S FX", "Live!SFX"),
                "msb": msb,
                "lsb": lsb,
                "pc": pc,
            }
        )
    return voices


STYLES: list[tuple[str, str]] = []


def add_styles(category: str, names: list[str]) -> None:
    for name in names:
        STYLES.append((category, name))


add_styles(
    "Pop",
    [
        "8Beat Modern", "8Beat Pop", "Pop Funk", "Pop Shuffle", "Pop Rock",
        "Guitar Pop", "Indie Pop", "Electro Pop", "Synth Pop", "80s Pop",
        "90s Pop", "Brit Pop", "City Pop", "Soft Pop", "Power Pop",
        "Pop Ballad", "Acoustic Pop", "Festival Pop", "Radio Pop", "Pop Groove",
        "Pop 16Beat", "Pop Chart", "Pop Anthem", "Pop Dance", "Pop Soul",
    ],
)
add_styles(
    "Entertainer",
    [
        "Showtime", "Big Entertainer", "TV Theme", "Variety Show", "Cabaret",
        "Music Hall", "Broadway Pop", "Circus March", "Vaudeville", "Game Show",
        "Opener", "Fanfare Pop", "Orchestra Hit", "Medley Pop", "Party Band",
        "Unplugged Show", "Club Entertainer", "Piano Bar", "Lounge Show", "Hit Parade",
    ],
)
add_styles(
    "Movie & Show",
    [
        "Blockbuster", "Adventure Film", "Epic Orchestra", "Suspense", "Western Movie",
        "Sci-Fi", "Romance Movie", "Action Cue", "Cartoon Score", "Fantasy Theme",
        "Detective", "War Epic", "Space Odyssey", "Superhero", "Silent Movie",
        "Musical Theatre", "Opera Pop", "Soundtrack Ballad", "Trailer", "Classic Film",
    ],
)
add_styles(
    "R&B",
    [
        "Modern R&B", "Soul Beat", "Neo Soul", "Funk Pop", "Disco Funk",
        "Motown", "Gospel Soul", "Quiet Storm", "Hip Hop Soul", "90s R&B",
        "New Jack", "Philly Soul", "Slow Jam", "Funk Shuffle", "Go Go",
        "Urban Groove", "R&B Ballad", "Club Soul", "Classic Funk", "Blues Soul",
    ],
)
add_styles(
    "Ballad",
    [
        "Piano Ballad", "Pop Ballad 12/8", "Love Song", "Soft Rock Ballad", "Soul Ballad",
        "Country Ballad", "Orchestral Ballad", "6/8 Ballad", "Acoustic Ballad", "Power Ballad",
        "Celtic Ballad", "Movie Ballad", "Gospel Ballad", "Easy Ballad", "Night Ballad",
        "Modern Ballad", "Slow Rock", "Unplugged Ballad", "Strings Ballad", "8Beat Ballad",
    ],
)
add_styles(
    "Dance",
    [
        "Dance Pop", "House", "Deep House", "EDM Anthem", "Trance",
        "Techno", "Euro Dance", "Disco Night", "Garage", "Drum & Bass",
        "Dubstep", "Electro House", "Club Dance", "90s Dance", "Italo Disco",
        "Synthwave", "Big Room", "Progressive", "Tropical House", "Afro House",
    ],
)
add_styles(
    "World",
    [
        "Celtic Folk", "Irish Jig", "Scottish", "Polka Folk", "Gypsy Swing",
        "Balkan", "Klezmer", "Greek", "Turkish Pop", "Arabic Pop",
        "Bollywood", "Bhangra", "Chinese Pop", "Japanese Pop", "Korean Pop",
        "African Pop", "Highlife", "Reggae", "Ska", "Calypso",
        "Soca", "Hawaiian", "Polynesian", "Andean", "Flamenco Pop",
    ],
)
add_styles(
    "Pianist",
    [
        "Pianist 8Beat", "Pianist Ballad", "Pianist Jazz", "Pianist Bossa", "Pianist Gospel",
        "Pianist Pop", "Pianist Shuffle", "Pianist Waltz", "Pianist 16Beat", "Pianist Country",
        "Pianist Blues", "Pianist Latin", "Pianist Rock", "Pianist Soul", "Pianist Free",
        "Pianist Classic", "Pianist New Age", "Pianist Boogie", "Pianist Swing", "Pianist Folk",
    ],
)
add_styles(
    "Jazz",
    [
        "Big Band", "Swingfox", "Jazz Club", "Bebop", "Cool Jazz",
        "Jazz Waltz", "Jazz Ballad", "Jazz Rock", "Fusion", "Smooth Jazz",
        "Dixieland", "Gypsy Jazz", "Organ Jazz", "Jazz Funk", "Modal Jazz",
        "Latin Jazz", "Jazz Samba", "Jazz Shuffle", "Piano Trio", "Jazz Blues",
    ],
)
add_styles(
    "Country",
    [
        "Country Pop", "Country Swing", "Country Rock", "Bluegrass", "Honky Tonk",
        "Country Ballad 2", "Nashville", "Country Shuffle", "Western Swing", "Country Two Step",
        "Country Waltz", "Americana", "Country Folk", "Country Train", "Country 8Beat",
        "Modern Country", "Country Gospel", "Outlaw", "Country Blues", "Country Disco",
    ],
)
add_styles(
    "Latin",
    [
        "Bossa Nova", "Samba", "Salsa", "Mambo", "Cha Cha",
        "Rumba", "Merengue", "Bachata", "Cumbia", "Reggaeton",
        "Tango", "Paso Doble", "Beguine", "Bolero", "Songo",
        "Latin Pop", "Latin Rock", "Afro Cuban", "Guaguanco", "Pachanga",
    ],
)
add_styles(
    "Ballroom",
    [
        "Slow Waltz", "Viennese Waltz", "Foxtrot", "Quickstep", "Tango Ballroom",
        "Slow Foxtrot", "Jive", "Cha Cha Ballroom", "Rumba Ballroom", "Samba Ballroom",
        "Paso Ballroom", "Swing Ballroom", "Polka Ballroom", "Mazurka", "Minuet",
        "English Waltz", "Boston Waltz", "Baroque Dance", "Classic Waltz", "Ballroom Mix",
    ],
)
add_styles(
    "Rock",
    [
        "Classic Rock", "Hard Rock", "Soft Rock", "Blues Rock", "Folk Rock",
        "Punk Rock", "Arena Rock", "Southern Rock", "Prog Rock", "Indie Rock",
        "Rock Shuffle", "Rock Ballad", "Surf Rock", "Glam Rock", "Metal Rock",
        "Rock 8Beat", "Rock 16Beat", "Boogie Rock", "Rockabilly", "Grunge",
    ],
)
add_styles(
    "Traditional",
    [
        "March", "Polka", "Oberkrainer", "French Musette", "German Waltz",
        "Alpine", "Brass Band", "Folk Dance", "Hymn", "Christmas 8Beat",
        "Christmas Waltz", "Christmas Ballad", "Church", "Fanfare", "Traditional Jazz",
        "Barbershop", "Celtic March", "Pipe Band", "Sea Shanty", "Festival March",
    ],
)
add_styles(
    "Ballad & Easy",
    [
        "Easy Listening", "Adult Contemporary", "Smooth Pop", "Night Club", "Cocktail",
        "New Age Pad", "Ambient Pop", "Chillout", "Lounge", "Downtempo",
        "Soft Funk", "Easy Shuffle", "Easy 8Beat", "Easy Latin", "Easy Jazz",
        "Movie Easy", "Soft Disco", "Soft House", "Soft Reggae", "Soft Country",
    ],
)


def dart_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace("'", "\\'")


def write_voices(voices: list[dict]) -> None:
    lines = [
        "// Generated from Yamaha PSR-SX900/SX700 Data List. Do not edit by hand.",
        "import 'voice.dart';",
        "",
        "const sx700Voices = <SxVoice>[",
    ]
    for v in voices:
        lines.append(
            "  SxVoice("
            f"name: '{dart_escape(v['name'])}', "
            f"category: '{dart_escape(v['category'])}', "
            f"type: '{dart_escape(v['type'])}', "
            f"msb: {v['msb']}, lsb: {v['lsb']}, pc: {v['pc']}),"
        )
    lines.append("];")
    lines.append("")
    (OUT_DIR / "voices.dart").write_text("\n".join(lines), encoding="utf-8")


def write_styles() -> None:
    lines = [
        "// PSR-SX700 style catalog. MIDI uses bank LSB = index ~/ 128, PC = index % 128 + 1,",
        "// plus Yamaha panel SysEx with the 0-based style index.",
        "import 'style.dart';",
        "",
        "const sx700Styles = <SxStyle>[",
    ]
    for i, (category, name) in enumerate(STYLES):
        lsb = i // 128
        pc = (i % 128) + 1
        lines.append(
            "  SxStyle("
            f"index: {i}, "
            f"name: '{dart_escape(name)}', "
            f"category: '{dart_escape(category)}', "
            f"msb: 0, lsb: {lsb}, pc: {pc}),"
        )
    lines.append("];")
    lines.append("")
    (OUT_DIR / "styles.dart").write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    text = DUMP.read_text(encoding="utf-8", errors="replace")
    voices = parse_voices(text)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    write_voices(voices)
    write_styles()
    print(f"voices={len(voices)} styles={len(STYLES)}")
    cats = sorted({v['category'] for v in voices})
    print("voice categories:", ", ".join(cats[:20]), "...")


if __name__ == "__main__":
    main()
