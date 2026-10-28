from pyonfx import Ass, Line, Utils

input_file = "ktime.ass"
output_file = "Fuusen Gamu.ass"

io = Ass(path_input=input_file, path_output=output_file, keep_original=False)
meta, styles, lines = io.get_data()


# ╭────────────────────────────────────────────────────────────────────────────╮
# │ Romaji                                                                     │
# ╰────────────────────────────────────────────────────────────────────────────╯
@io.track
def romaji(line: Line, ln: Line):

    syls = list(Utils.all_non_empty(line.syls))

    for i, syl in enumerate(syls):
        # ╭────────────────────────────────────────────────────────────────────────────╮
        # │ Leadin Effect                                                              │
        # ╰────────────────────────────────────────────────────────────────────────────╯
        # leadin = min(line.leadin * 7 // 10, 400)
        leadin = 0
        ln.layer = 0
        ln.actor = ""
        ln.start_time = line.start_time - leadin
        ln.end_time = line.start_time + syl.start_time

        tags = rf"\an2\pos({syl.center:.3f},{syl.bottom:.3f})\blur0.65"
        ln.text = f"{{{tags}}}{syl.text}"
        io.write_line(ln)

        # ╭────────────────────────────────────────────────────────────────────────────╮
        # │ Main Effect                                                                │
        # ╰────────────────────────────────────────────────────────────────────────────╯
        ln.layer = 2
        ln.actor = ""
        ln.start_time = line.start_time + syl.start_time
        ln.end_time = line.start_time + syl.end_time

        # Original values
        fscy = line.styleref.scale_y

        # New values
        new_fscy = fscy * 1.4

        tags = (
            rf"\an2\pos({syl.center:.3f},{syl.bottom:.3f})\blur0.65"
            rf"\t(0,{min(100, syl.duration * 0.4)},\fscy{new_fscy})"
            rf"\t({min(100, syl.duration * 0.4)},{syl.duration},\fscy{fscy})"
        )
        ln.text = f"{{{tags}}}{syl.text}"

        io.write_line(ln)

        # ╭────────────────────────────────────────────────────────────────────────────╮
        # │ Leadout Effect                                                             │
        # ╰────────────────────────────────────────────────────────────────────────────╯
        # leadout = min(line.leadout * 3 // 10, 400)
        leadout = 0
        ln.layer = 0
        ln.actor = ""
        ln.start_time = line.start_time + syl.end_time
        ln.end_time = line.end_time + leadout

        tags = rf"\an2\pos({syl.center:.3f},{syl.bottom:.3f})\blur0.65"
        ln.text = f"{{{tags}}}{syl.text}"

        io.write_line(ln)


# ╭────────────────────────────────────────────────────────────────────────────╮
# │ Translation                                                                │
# ╰────────────────────────────────────────────────────────────────────────────╯
@io.track
def sub(line: Line, ln: Line):
    # leadin = min(line.leadin * 7 // 10, 400)
    # leadout = min(line.leadout * 3 // 10, 400)
    leadin = 0
    leadout = 0
    ln.actor = ""
    ln.start_time = line.start_time - leadin
    ln.end_time = line.end_time + leadout
    ln.layer = 0

    pos = line.actor.replace(";", ",")
    tags = rf"\blur0.65{pos}"
    ln.text = f"{{{tags}}}{line.text}"
    io.write_line(ln)


# Generating lines
for line in lines:
    if line.actor == "sync":
        io.write_line(line)
    elif line.comment:
        continue
    elif line.styleref.alignment >= 7:
        romaji(line, line.copy())
    else:
        sub(line, line.copy())

io.save()
