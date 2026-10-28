export script_name = "Gintama Notes"
export script_description = "Creates reference notes for gintama."
export script_version = "0.0.1"
export script_author = "PhosCity"
export script_namespace = "Phos.GintamaNotes"

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


main = (sub, sel) ->
    AssfPlus._util.windowAssertError AssfPlus._util.checkVideoIsOpen!, "You must have video open to use this script."

    offset = 10     -- how big the box should be compared to text in pixels
	radius = 10     -- radius of the corners
	k = 0.55228475  -- bezier constant

    lines = LineCollection sub, sel
    return if #lines.lines == 0

    toDelete, toAdd = {}, {}

    lines\runCallback (lines, line, i) ->
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

    for ln in *toAdd
      lines\addLine ln

    lines\insertLines!
    lines\deleteLines toDelete


depctrl\registerMacro main
