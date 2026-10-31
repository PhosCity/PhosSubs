export script_name = "Gintama"
export script_description = "Various stuff for gintama project."
export script_version = "0.0.2"
export script_author = "PhosCity"
export script_namespace = "Phos.Gintama"

DependencyControl = require "l0.DependencyControl"
depctrl = DependencyControl{
    feed: "https://raw.githubusercontent.com/PhosCity/Aegisub-Scripts/main/DependencyControl.json",
    {
        {"a-mo.LineCollection", version: "1.3.0", url: "https: //github.com/TypesettingTools/Aegisub-Motion",
            feed: "https: //raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"},
        {"l0.ASSFoundation", version: "0.5.0", url: "https: //github.com/TypesettingTools/ASSFoundation",
            feed: "https: //raw.githubusercontent.com/TypesettingTools/ASSFoundation/master/DependencyControl.json"},
        {"phos.AssfPlus", version: "1.0.5", url: "https://github.com/PhosCity/Aegisub-Scripts",
            feed: "https://raw.githubusercontent.com/PhosCity/Aegisub-Scripts/main/DependencyControl.json"},
    },
}
LineCollection, ASS, AssfPlus = depctrl\requireModules!

notes = (sub, sel) ->
    AssfPlus._util.windowAssertError AssfPlus._util.checkVideoIsOpen!, "You must have video open to use this script."

    offset = 10     -- how big the box should be compared to text in pixels
	radius = 10     -- radius of the corners
	k = 0.55228475  -- bezier constant

    lines = LineCollection sub, sel
    return if #lines.lines == 0

    toDelete, toAdd = {}, {}

    lines\runCallback ((lines, line, i) ->
        if line.style != "Notes"
            aegisub.log "The style must be \"Note\". Got \"#{line.style}\""
            aegisub.cancel!

        data = ASS\parse line
        table.insert toDelete, line

        line.layer += 1
        data\replaceTags {
            ASS\createTag 'outline', 0
            ASS\createTag 'color1', 0, 0, 0
            ASS\createTag 'blur', 0.4
        }
        table.insert toAdd, ASS\createLine { line }
        line.layer -= 1

        left, top, right, bottom = AssfPlus.lineData.getBoundingBox data, false, true, true

        left -= offset
        top -= offset
        right += offset
        bottom += offset

        shape = "m #{left + radius} #{top} " ..
            "l #{right - radius} #{top} " ..
            "b #{right - radius * k} #{top} #{right} #{top + radius * k} #{right} #{top + radius} " ..
            "l #{right} #{bottom - radius} " ..
            "b #{right} #{bottom - radius * k} #{right - radius * k} #{bottom} #{right - radius} #{bottom} " ..
            "l #{left + radius} #{bottom} " ..
            "b #{left + radius * k} #{bottom} #{left} #{bottom - radius * k} #{left} #{bottom - radius} " ..
            "l #{left} #{top + radius} " ..
            "b #{left} #{top + radius * k} #{left + radius * k} #{top} #{left + radius} #{top}"


        data\removeSections 1, #data.sections
        drawing = ASS.Draw.DrawingBase {str: shape}
        drawing = data\insertSections ASS.Section.Drawing {drawing}

        data\insertTags {
            ASS\createTag 'align', 7
            ASS\createTag 'position', 0, 0
            ASS\createTag 'color1', 255, 255, 255
            ASS\createTag 'alpha1', 0x70
            ASS\createTag 'blur', 0.5
        }

        table.insert toAdd, ASS\createLine { line }
    ), true

    for ln in *toAdd
      lines\addLine ln

    lines\insertLines!
    lines\deleteLines toDelete


preprocessing = (subs, sel) ->

    -- We first determine the fold ids we can use.
    -- Genereally there shouldn't be any folds but we must be sure.
    parseLineFold = (line) ->
        return if not line.extra
        info = line.extra["_aegi_folddata"]
        return if not info
        side, collapsed, id = info\match("^(%d+);(%d+);(%d+)$")
        return {:side, :collapsed, :id}

    highestFoldId = 0
    for i = 1, #subs
        continue unless subs[i].class == "dialogue"
        line = subs[i]

        -- Collect fold data
        foldData = parseLineFold line
        highestFoldId = math.max(highestFoldId, foldData.id) if foldData

    foldId = highestFoldId + 1

    -- ==========SCRIPT INFO==================
    --Get the information about the video
    xres, yres, _, _ = aegisub.video_size()
    unless xres         -- Video is not loaded
        aegisub.log "You need to load the video when preprocessing the script."
        aegisub.cancel!

    infoIndex, infoLine = 0, {}
    for i = 1, #subs
        if subs[i].class == "info"
            line = subs[i]
            infoIndex = i
            infoLine = line
            line.value = tostring(xres) if line.key == "PlayResX"
            line.value = tostring(yres) if line.key == "PlayResY"
            line.value = tostring(xres) if line.key == "LayoutResX"
            line.value = tostring(yres) if line.key == "LayoutResY"
            line.value = "TV.601" if line.key == "YCbCr Matrix"
            subs[i] = line
        break if subs[i].class=="dialogue"

    -- ==========MANAGE STYLES==================
    for i = 1, #subs
        if subs[i].class == "style"
            style = subs[i].name
            if style\match("^Main$") or style\match("Thoughts") or style\match("Flashbacks") or style\match("Narrator") or style\match("Title") or style\match("Caption") or style\match("Secondary")
                btn, res = aegisub.dialog.display({
                    { x: 0, y: 0, class: "label", label: "It appears that this file already has styles added."},
                    { x: 0, y: 1, class: "label", label: "It is not recommended to run this in a script that has already been timed/edited.", width: 10 },
                    { x: 0, y: 2, class: "label", label: "The script will replace all styles and add new muxer markers.", width: 10 },
                    { x: 0, y: 3, class: "label", label: "Do you want to proceed?", width: 10 },
                }, {"Yes", "No"})
                return if btn == "No"
                break
        break if subs[i].class=="dialogue"

    -- ==========DELETE ALL OLD STYLES==================
    for i = 1, #subs
        if subs[i].class == "style"
            subs.delete(i)
        break if subs[i].class=="dialogue"

    -- ==========ADD NEW STYLES==================
    stl = {
        {name: "Main",           color1: "&H00FFFFFF&", color2: "&H000000FF&", color3: "&H00000000&", color4: "&H96000000&", fontname: "Montara-Gothic",                    fontsize: 38, spacing: 0.5, italic: false, strikeout: false, bold: false, underline: false, margin_t: 30,  margin_r: 45, margin_b: 30,  margin_l: 45, angle: 0, align: 2, scale_y: 100, scale_x: 100, outline: 2,   shadow: 2, encoding: 0, borderstyle: 1, section: "[V4+ Styles]", class: "style"}
        {name: "Thoughts",       color1: "&H00FFFFFF&", color2: "&H00FFFFFF&", color3: "&H00525252&", color4: "&H96000000&", fontname: "Montara-Gothic",                    fontsize: 38, spacing: 0.5, italic: false, strikeout: false, bold: false, underline: false, margin_t: 30,  margin_r: 45, margin_b: 30,  margin_l: 45, angle: 0, align: 2, scale_y: 100, scale_x: 100, outline: 2,   shadow: 2, encoding: 0, borderstyle: 1, section: "[V4+ Styles]", class: "style"}
        {name: "Flashbacks",     color1: "&H00FFFFFF&", color2: "&H00FFFFFF&", color3: "&H00525252&", color4: "&H96000000&", fontname: "Montara-Italic",                    fontsize: 38, spacing: 0.5, italic: true,  strikeout: false, bold: false, underline: false, margin_t: 30,  margin_r: 45, margin_b: 30,  margin_l: 45, angle: 0, align: 2, scale_y: 100, scale_x: 100, outline: 2,   shadow: 2, encoding: 0, borderstyle: 1, section: "[V4+ Styles]", class: "style"}
        {name: "Secondary",      color1: "&H00D6D6D6&", color2: "&H00FFFFFF&", color3: "&H00000000&", color4: "&H96000000&", fontname: "Montara-Gothic",                    fontsize: 38, spacing: 0.5, italic: false, strikeout: false, bold: false, underline: false, margin_t: 30,  margin_r: 45, margin_b: 30,  margin_l: 45, angle: 0, align: 2, scale_y: 100, scale_x: 100, outline: 2,   shadow: 2, encoding: 0, borderstyle: 1, section: "[V4+ Styles]", class: "style"}
        {name: "Narrator",       color1: "&H00FFFFFF&", color2: "&H000000FF&", color3: "&H00000000&", color4: "&H78000000&", fontname: "Montara-Italic",                    fontsize: 38, spacing: 0.5, italic: true,  strikeout: false, bold: false, underline: false, margin_t: 30,  margin_r: 45, margin_b: 30,  margin_l: 45, angle: 0, align: 2, scale_y: 100, scale_x: 100, outline: 2,   shadow: 2, encoding: 0, borderstyle: 1, section: "[V4+ Styles]", class: "style"}
        {name: "Title",          color1: "&H00FEFEFE&", color2: "&H000000FF&", color3: "&H00000000&", color4: "&H00000000&", fontname: "HOT-KyoMadokaKanalarge Std R Strp", fontsize: 40, spacing: 0.5, italic: false, strikeout: false, bold: false, underline: false, margin_t: 360, margin_r: 15, margin_b: 360, margin_l: 15, angle: 0, align: 2, scale_y: 100, scale_x: 100, outline: 2.5, shadow: 0, encoding: 0, borderstyle: 1, section: "[V4+ Styles]", class: "style"}
        {name: "Captions",       color1: "&H00FFFFFF&", color2: "&H000000FF&", color3: "&H00000000&", color4: "&H00000000&", fontname: "Montara-Gothic",                    fontsize: 30, spacing: 0.5, italic: false, strikeout: false, bold: false, underline: false, margin_t: 30,  margin_r: 15, margin_b: 30,  margin_l: 15, angle: 0, align: 2, scale_y: 100, scale_x: 100, outline: 3,   shadow: 0, encoding: 0, borderstyle: 1, section: "[V4+ Styles]", class: "style"}
        {name: "Warning",        color1: "&H00FFFFFF&", color2: "&H000000FF&", color3: "&H00000000&", color4: "&H00000000&", fontname: "Montara-Gothic",                    fontsize: 30, spacing: 0.5, italic: false, strikeout: false, bold: false, underline: false, margin_t: 10,  margin_r: 10, margin_b: 10,  margin_l: 10, angle: 0, align: 2, scale_y: 100, scale_x: 100, outline: 2,   shadow: 2, encoding: 0, borderstyle: 1, section: "[V4+ Styles]", class: "style"}
        {name: "Preview Bottom", color1: "&H00FFFFFF&", color2: "&H000000FF&", color3: "&H003B20EB&", color4: "&H00000000&", fontname: "BurbankSmall-Black",                fontsize: 32, spacing: 1,   italic: false, strikeout: false, bold: true,  underline: false, margin_t: 7,   margin_r: 15, margin_b: 7,   margin_l: 15, angle: 0, align: 2, scale_y: 100, scale_x: 104, outline: 3,   shadow: 0, encoding: 0, borderstyle: 1, section: "[V4+ Styles]", class: "style"}
        {name: "Preview Top",    color1: "&H00FFFFFF&", color2: "&H000000FF&", color3: "&H003B20EB&", color4: "&H00000000&", fontname: "BurbankSmall-Black",                fontsize: 32, spacing: 1,   italic: false, strikeout: false, bold: true,  underline: false, margin_t: 10,  margin_r: 15, margin_b: 10,  margin_l: 15, angle: 0, align: 8, scale_y: 100, scale_x: 104, outline: 3,   shadow: 0, encoding: 0, borderstyle: 1, section: "[V4+ Styles]", class: "style"}
        {name: "Preview",        color1: "&H00FFFFFF&", color2: "&H000000FF&", color3: "&H00131313&", color4: "&H00000000&", fontname: "DFHSMincho StdN W7 Strp",           fontsize: 50, spacing: 0.5, italic: false, strikeout: false, bold: false, underline: false, margin_t: 0,   margin_r: 90, margin_b: 0,   margin_l: 15, angle: 0, align: 9, scale_y: 100, scale_x: 100, outline: 1.2, shadow: 0, encoding: 0, borderstyle: 1, section: "[V4+ Styles]", class: "style"}
        {name: "Notes",          color1: "&H00FFFFFF&", color2: "&H000000FF&", color3: "&H00000000&", color4: "&H00000000&", fontname: "RodinProN-DB",                      fontsize: 20, spacing: 0,   italic: false, strikeout: false, bold: true,  underline: false, margin_t: 18,  margin_r: 35, margin_b: 18,  margin_l: 35, angle: 0, align: 8, scale_y: 100, scale_x: 100, outline: 3,   shadow: 0, encoding: 1, borderstyle: 1, section: "[V4+ Styles]", class: "style"}
    }

    for i = 1, #subs
        index = i - 1
        if subs[i].class == "dialogue"
            for style in *stl
                subs.insert(index, style)
                index += 1
            break

    -- ==========CHANGE ALL LINES TO STYLES MAIN==================
    for i = 1, #subs
      continue unless subs[i].class == "dialogue"
      line = subs[i]
      line.style = "Main"
      subs[i] = line

    -- ==========ADD CHAPTER AND KARAOKE MARKERS==================
    line_top = {
        { actor: "",      class: "dialogue", comment: true,  effect: "", start_time: 0,      end_time: 0,      layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",    text: "========================CHAPTERS AND OPENINGS=====================",  foldOpenId: foldId }
        { actor: "chptr", class: "dialogue", comment: true,  effect: "", start_time: 0,      end_time: 0,      layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",    text: "{Intro}"}
        { actor: "chptr", class: "dialogue", comment: true,  effect: "", start_time: 0,      end_time: 0,      layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",    text: "{Opening}"}
        { actor: "chptr", class: "dialogue", comment: true,  effect: "", start_time: 0,      end_time: 0,      layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",    text: "{Info A}"}
        { actor: "chptr", class: "dialogue", comment: true,  effect: "", start_time: 0,      end_time: 0,      layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",    text: "{Part A}"}
        { actor: "chptr", class: "dialogue", comment: true,  effect: "", start_time: 0,      end_time: 0,      layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",    text: "{Part B}"}
        { actor: "chptr", class: "dialogue", comment: true,  effect: "", start_time: 0,      end_time: 0,      layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",    text: "{Ending}"}
        { actor: "chptr", class: "dialogue", comment: true,  effect: "", start_time: 0,      end_time: 0,      layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",    text: "{Preview}"}
        { actor: "chptr", class: "dialogue", comment: true,  effect: "", start_time: 0,      end_time: 0,      layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",    text: "{Outro}"}
        { actor: "OP",    class: "dialogue", comment: true,  effect: "", start_time: 0,      end_time: 0,      layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",    text: ""}
        { actor: "ED",    class: "dialogue", comment: true,  effect: "", start_time: 0,      end_time: 0,      layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",    text: ""}
        { actor: "",      class: "dialogue", comment: false, effect: "", start_time: 0,      end_time: 9990,   layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Warning", text: "{\\fscx0\\fscy0\\clip(0, 0, 0, 0)\\org(0, 0)}Your media player does not support the subtitle format used in this episode.\\NSubtitles will likely not function properly.\\NPlease use one of the recommended video players, preferably mpv:\\Nhttps://mpv.io"}
        { actor: "",      class: "dialogue", comment: false, effect: "", start_time: 152510, end_time: 162500, layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Warning", text: "{\\fscx0\\fscy0\\clip(0, 0, 0, 0)\\org(0, 0)}Your media player does not support the subtitle format used in this episode.\\NSubtitles will likely not function properly.\\NPlease use one of the recommended video players, preferably mpv:\\Nhttps://mpv.io"}
        { actor: "",      class: "dialogue", comment: true,  effect: "", start_time: 0,      end_time: 0,      layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",    text: "========================CHAPTERS AND OPENINGS=====================",  foldCloseId: foldId }
        { actor: "",      class: "dialogue", comment: true,  effect: "", start_time: 0,      end_time: 0,      layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",    text: "===============================DIALOGUE============================", foldOpenId: foldId + 1 }
    }

    line_bottom = {
        { actor: "", class: "dialogue", comment: true,  effect: "", start_time: 0, end_time: 0, layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",  text: "===============================DIALOGUE============================", foldCloseId: foldId + 1 }
        { actor: "", class: "dialogue", comment: true,  effect: "", start_time: 0, end_time: 0, layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",  text: "============================SIGNS AND TITLE=========================", foldOpenId: foldId + 2 }
        { actor: "", class: "dialogue", comment: true,  effect: "", start_time: 0, end_time: 0, layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",  text: "============================SIGNS AND TITLE=========================", foldCloseId: foldId + 2 }
        { actor: "", class: "dialogue", comment: true,  effect: "", start_time: 0, end_time: 0, layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",  text: "===============================PREVIEW==============================", foldOpenId: foldId + 3 }
        { actor: "", class: "dialogue", comment: true,  effect: "", start_time: 0, end_time: 0, layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",  text: "===============================PREVIEW==============================", foldCloseId: foldId + 3 }
        { actor: "", class: "dialogue", comment: true,  effect: "", start_time: 0, end_time: 0, layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",  text: "==============================REFERENCES=============================", foldOpenId: foldId + 4 }
        { actor: "", class: "dialogue", comment: true,  effect: "", start_time: 0, end_time: 0, layer: 0, margin_l: 0, margin_r: 0, margin_t: 0, section: "[Events]", style: "Main",  text: "==============================REFERENCES=============================", foldCloseId: foldId + 4 }
    }

    addFolds = (line) ->
        openID = line["foldOpenId"]
        closeID = line["foldCloseId"]
        if openID and closeID
            aegisub.log "A single line cannot have both fold open id and close id."
            aegisub.cancel!

        if openID
            line["extra"] or= {}
            line["extra"]["_aegi_folddata"] = "0;1;#{openID}"

        if closeID
            line["extra"] or= {}
            line["extra"]["_aegi_folddata"] = "1;1;#{closeID}"


    -- Add lines at top of the file
    for i = 1, #subs
        if subs[i].class == "dialogue"
            index = i

            for line in *line_top
                addFolds line
                subs.insert(index, line)
                index += 1
            break

    -- Add lines at bottom of the file
    for line in *line_bottom
        addFolds line
        subs.insert(#subs+1, line)


depctrl\registerMacros{
    { "Preprocessing", "Preprocess the subtitle file before doing anything", preprocessing }
    { "Notes",         "Add reference notes",                                notes }
}
