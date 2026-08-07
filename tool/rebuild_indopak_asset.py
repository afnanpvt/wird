import argparse
import json
import re
import zipfile
from collections import defaultdict
from pathlib import Path

PUA_RE = re.compile(r"[\uE000-\uF8FF\U000F0000-\U000FFFFD\U00100000-\U0010FFFD]")
WHITESPACE_RE = re.compile(r"\s+")


def _read_source(path: Path) -> dict[str, dict[str, str]]:
    if path.suffix.lower() == ".zip":
        with zipfile.ZipFile(path) as archive:
            json_entries = [name for name in archive.namelist() if name.lower().endswith(".json")]
            if not json_entries:
                raise ValueError(f"No JSON file found in archive: {path}")
            with archive.open(json_entries[0]) as source:
                return json.loads(source.read().decode("utf-8"))

    return json.loads(path.read_text(encoding="utf-8"))


def _clean_text(text: str) -> str:
    cleaned = PUA_RE.sub("", text)
    cleaned = WHITESPACE_RE.sub(" ", cleaned)
    return cleaned.strip()


def rebuild_asset(source_path: Path, output_path: Path) -> int:
    words_by_ayah: dict[tuple[int, int], list[tuple[int, str]]] = defaultdict(list)

    for word in _read_source(source_path).values():
        surah = int(word["surah"])
        ayah = int(word["ayah"])
        order = int(word["word"])
        words_by_ayah[(surah, ayah)].append((order, word["text"].strip()))

    verses = []
    for (surah, ayah) in sorted(words_by_ayah):
        ordered_words = [text for _, text in sorted(words_by_ayah[(surah, ayah)]) if text]
        joined = " ".join(ordered_words)
        verses.append({"chapter": surah, "verse": ayah, "text": _clean_text(joined)})

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps({"quran": verses}, ensure_ascii=False, separators=(",", ": ")),
        encoding="utf-8",
    )
    return len(verses)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build assets/data/quran_ar_indopak.json from the supplied word-by-word Indo-Pak source.",
    )
    parser.add_argument("source", help="Path to the source JSON file or zip archive.")
    parser.add_argument(
        "--output",
        default="assets/data/quran_ar_indopak.json",
        help="Path to the generated ayah-level JSON asset.",
    )
    args = parser.parse_args()

    source_path = Path(args.source)
    output_path = Path(args.output)
    verse_count = rebuild_asset(source_path, output_path)
    print(f"Wrote {verse_count} ayahs to {output_path}")


if __name__ == "__main__":
    main()
