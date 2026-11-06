# Gintama

![Banner](https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx918-iOaeBVUn4uK7.jpg)

[Anilist Link](https://anilist.co/anime/918/Gintama/)

## Changes Made

- The major changes made is just Gintama DVD subs with typesetting and dialogue
    styling.
- References were added but better research could be done on them and added.
- Openings and Endings have simple karaoke made for them.

## Video Source

The source is CBT which is just Yousei-raws + Crunchyroll
since [SeaDex](https://seadex.moe/) suggested this is the best release.

## How To Use

- Download the video.
- Batch rename the videos to episode number only. There are many software to do
    this easily. For example, episode 3 becomes `003.mkv`. All episodes are padded
    with 0 upto 3 digits. There are cases of double episodes like episode 1 and
    2 merged to same video. In that case, rename it to the first one i.e
    `001.mkv`. Also see below for all double episodes list.

- Move video to the folder named `video`.
- Make sure you have installed muxtools from
    [Github](https://github.com/Jaded-Encoding-Thaumaturgy/muxtools) or
    [pypi](https://pypi.org/project/muxtools/).
- Go to the folder where you will find `mux.py` file. In order to mux episode 1,
    run the command

    ```sh
    python mux.py 1
    ```

    In order to mux episode 1, 3 and 6, run the command

    ```sh
    python mux.py 1 3 6
    ```

    In order to mux all episodes between two episodes (1 and 201 for example), run

    ```sh
    python mux.py -b 1 201
    ```

- The muxed files will be present in the folder named `Release`.

## Double Episodes

| Double Episodes | Episode Number Used In This Project |
| ------------- | ------------- |
| 1 and 2 | 1 |
