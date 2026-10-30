import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent

# Folders to process
TARGET_FOLDERS = [
    "Gintama/01 Gintama",
    # Add more
]

OUTPUT_FILE = Path("references.md")


def extract_notes(ass_file):
    notes = []

    with ass_file.open("r", encoding="utf-8-sig", errors="replace") as f:
        for line in f:
            if not line.startswith("Dialogue:"):
                continue

            # ASS format:
            # Dialogue: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text

            fields = line.strip().split(",", 9)

            if len(fields) != 10:
                continue

            timestamp = fields[1].strip()
            style = fields[3].strip()
            text = fields[9].strip()

            # Only extract Notes style
            if style != "Notes":
                continue

            # Ignore the line with shapes
            if re.search(r"\\p[1-9]\d*", text):
                continue

            # Remove ASS override tags, e.g. {\bord0\blur0.4}
            text = re.sub(r"\{[^}]*\}", "", text)

            # Convert ASS line breaks and hard spaces
            text = text.replace(r"\N", "<br>")
            text = text.replace(r"\n", "<br>")
            text = text.replace(r"\h", " ")

            text = " ".join(text.split())

            if not text:
                continue

            # Escape Markdown table separators
            text = text.replace("|", r"\|")

            notes.append((timestamp, text))

    return notes


def main():
    for folder in TARGET_FOLDERS:
        anime_dir = REPO_ROOT / folder

        if not anime_dir.is_dir():
            print(f"Skipping: {folder} (folder not found)")
            continue

        output = ["# References", ""]

        episode_dirs = sorted(
            [
                folder
                for folder in anime_dir.iterdir()
                if folder.is_dir() and folder.name.isdigit()
            ],
            key=lambda folder: int(folder.name),
        )

        for episode_dir in episode_dirs:
            episode_notes = []

            # Find all ASS subtitle files in the episode folder
            ass_files = sorted(episode_dir.glob("* en.ass"))

            for ass_file in ass_files:
                episode_notes.extend(extract_notes(ass_file))

            if not episode_notes:
                continue

            output.append(f"## {episode_dir.name}")
            output.append("")
            output.append("| Timestamp | Reference |")
            output.append("|---|---|")

            for timestamp, reference in episode_notes:
                output.append(f"| {timestamp} | {reference} |")

            output.append("")

        output_file = anime_dir / "references.md"

        output_file.write_text("\n".join(output), encoding="utf-8")

        print(f"Generated {output_file.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
