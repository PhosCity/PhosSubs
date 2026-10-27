import argparse
import shutil
from pathlib import Path

from muxtools import Chapters, Premux, Setup, SubFile, mux

terminal_width = shutil.get_terminal_size().columns
current_dir = Path(__file__).parent


class RangeDict:
    def __init__(self, *, strict=False):
        self._data = {}
        self.strict = strict

    def __setitem__(self, key, value):
        if isinstance(key, slice):
            start = key.start
            stop = key.stop
            step = key.step or 1

            # Make the stop value inclusive
            keys = range(start, stop + (1 if step > 0 else -1), step)

            if self.strict:
                conflicts = [k for k in keys if k in self._data]
                if conflicts:
                    raise KeyError(f"Conflicting keys: {conflicts}")

            for k in keys:
                self._data[k] = value
        else:
            if self.strict and key in self._data:
                raise KeyError(f"Key already exists: {key}")
            self._data[key] = value

    def __getitem__(self, key):
        return self._data[key]

    def __contains__(self, key):
        return key in self._data

    def __repr__(self):
        return repr(self._data)

    def get(self, key, default=None):
        return self._data.get(key, default)

    def keys_with_value(self, value):
        return [k for k, v in self._data.items() if v == value]


# ╭─────────────────────────────────────────────────────────────────────────────╮
# │ Opening Paths                                                               │
# ╰─────────────────────────────────────────────────────────────────────────────╯
opening = RangeDict()
opening[1:24] = current_dir / "Openings" / "01 Pray" / "Pray.ass"

# ╭─────────────────────────────────────────────────────────────────────────────╮
# │ Ending Paths                                                                │
# ╰─────────────────────────────────────────────────────────────────────────────╯
ending = RangeDict()
ending[1:13] = current_dir / "Endings" / "01 Fuusen Gamu" / "Fuusen Gamu.ass"

# ╭─────────────────────────────────────────────────────────────────────────────╮
# │ Merged Episodes                                                             │
# ╰─────────────────────────────────────────────────────────────────────────────╯
double_episodes = RangeDict()
double_episodes[1:2] = 1

# ╭─────────────────────────────────────────────────────────────────────────────╮
# │ Title List                                                                  │
# ╰─────────────────────────────────────────────────────────────────────────────╯
all_title = {
    1: "You Guys!! Do You Even Have Gintama?!",
    3: "Nobody with Naturally Wavy Hair Can be That Bad!",
}


def print_header(header: str, dash_type="-") -> None:
    print("\n")
    dashes = dash_type * terminal_width
    padding = int((len(dashes) + len(header)) / 2)
    print(dashes)
    print(header.rjust(padding))
    print(dashes)


def format_episode(ep) -> str:
    related = double_episodes.keys_with_value(ep) or [ep]
    related = [f"{n:03d}" for n in related]

    if len(related) == 1:
        return str(related[0])

    return f"{', '.join(map(str, related[:-1]))} & {related[-1]}"


def mux_file(ep):
    episode = f"{ep:03d}"  # Format to have padded zeros
    timesource = "24000/1001"

    # Folders
    episode_folder = current_dir / episode
    video_folder = current_dir / "video"
    font_folder = current_dir / "fonts"
    release_folder = current_dir / "Release"

    # Files
    subtitle_file = SubFile(episode_folder / f"{episode} en.ass")
    video_file = str(video_folder / f"{episode}.mkv")

    # Names
    formatted_ep = format_episode(ep)
    title = f"{formatted_ep} {all_title[ep]}"

    Setup(
        episode,
        None,
        out_dir=str(release_folder),
        out_name=title,
        mkv_title_naming=title,
        work_dir=str(Path("build") / "muxtools"),
        clean_work_dirs=True,
    )

    video = Premux(
        video_file,
        keep_attachments=False,
        keep_chapters=False,
        subtitles=None,
        mkvmerge_args='--no-global-tags --track-name 0:"[CBT] Gintama DVDrip"',
    )

    print_header("Generating Chapters...")
    chapters = Chapters.from_sub(
        subtitle_file, timesource=timesource, use_actor_field=True
    )

    # ╭──────────────────────────────────────────────────────────────────────────────╮
    # │ Karaoke Subtitles                                                            │
    # ╰──────────────────────────────────────────────────────────────────────────────╯
    if ep in opening:
        print_header("Merging Opening...")
        subtitle_file.merge(
            opening[ep],
            sync="OP",
            sync2="sync",
            use_actor_field=True,
            no_error=True,
            timesource=timesource,
        )
    if ep in ending:
        print_header("Merging Ending...")
        subtitle_file.merge(
            ending[ep],
            sync="ED",
            sync2="sync",
            use_actor_field=True,
            no_error=True,
            timesource=timesource,
        )

    # ╭──────────────────────────────────────────────────────────────────────────────╮
    # │ Clean Subtitles                                                              │
    # ╰──────────────────────────────────────────────────────────────────────────────╯
    print_header("Cleaning Subtitles...")
    subtitle_file.clean_styles().clean_garbage().clean_extradata().clean_comments()

    # ╭──────────────────────────────────────────────────────────────────────────────╮
    # │ Font Collection                                                              │
    # ╰──────────────────────────────────────────────────────────────────────────────╯
    print_header("Collecting fonts for English subs...")
    fonts = subtitle_file.collect_fonts(
        use_system_fonts=False,
        search_current_dir=False,
        additional_fonts=font_folder,
        error_missing=True,
    )

    # ╭──────────────────────────────────────────────────────────────────────────────╮
    # │ Muxing                                                                       │
    # ╰──────────────────────────────────────────────────────────────────────────────╯
    print_header("Muxing...", dash_type="=")
    mux(video, subtitle_file.to_track("English", "en"), *fonts, chapters)


def main():
    # ╭─────────────────────────────────────────────────────────────────────────────╮
    # │ Arguments                                                                   │
    # ╰─────────────────────────────────────────────────────────────────────────────╯
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "episodes",
        nargs="*",
        type=int,
        help="Numbers to process individually",
    )
    parser.add_argument(
        "-b",
        "--batch",
        nargs=2,
        type=int,
        metavar=("START", "END"),
        help="Process a range of numbers",
    )
    args = parser.parse_args()

    if args.batch is not None:
        start, end = map(int, args.batch)
        episodes = sorted(
            {double_episodes.get(ep, ep) or ep for ep in range(start, end + 1)}
        )
    else:
        episodes = list(
            dict.fromkeys(double_episodes.get(ep, ep) for ep in args.episodes)
        )

    # ╭─────────────────────────────────────────────────────────────────────────────╮
    # │ Process episodes                                                            │
    # ╰─────────────────────────────────────────────────────────────────────────────╯
    for ep in episodes:
        print_header(f"Processing {ep}...", dash_type="=")
        mux_file(ep)


if __name__ == "__main__":
    main()
