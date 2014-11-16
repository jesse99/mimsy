-- Set the back color of the current line.

color = "PeachPuff"

function init(script_dir)
	mimsy:set_extension_name("highlight-line")
	mimsy:set_extension_version("1.0")
	
	-- Temporary attributes are a bit annoying because they don't affect the typing attributes
	-- so edits don't look right. It'd be possible to use normal attributes but then we'd have
	-- to somehow remove them before saving and copying. So, for now, we just re-apply the line
	-- highlighting after normal styles are applied to fix the line up.
	mimsy:watch_file(1.0, "/Volumes/Mimsy/extension-settings-changed", "load_prefs")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/text-document/line-number", "onLineChanged")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/text-document/applied-styles", "onLineChanged")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/text-document/main-changed", "onMainChanged")

    assert(dofile(script_dir .. "/helpers.inc.lua"))

    load_prefs()
end

function load_prefs()
    local file_name = "highlight-line.lua"
local defaults = string.format([==[
prefs = {
    -- This is the background line color. Standard Mimsy
    -- color names may be used.
    color = "%s"
}
]==], color)
    local prefs = load_prefs_helper(file_name, defaults)
    if prefs then
        color = prefs.color
    end
end

-- The classy way to do this is to store the state of the current line highlighting within a
-- file in "text-document/key-values/" and remove the associated background color when the
-- line changes. Unfortunately we don't always get notified sufficiently often (I think
-- Cocoa sometimes coalesces text edited notifications). So we'll just brute force it to
-- ensure the display stays consistent.
--
-- This might impact other extensions that manipulate the back color but those will always
-- be iffy with this extension (unless they're very transient).
function onLineChanged()
    -- First remove all the old highlighting.
    local length = read_proc_file("text-document/length")
    write_proc_file("text-document/remove-temp-back-color", string.format("0\f%s", length))

    -- Then, if only a single line is selected, highlight the current line.
    local line = read_proc_file("text-document/line-number")
    if line ~= "-1" then
        local new_text = read_proc_file("text-document/line-selection")
        local new_selection = split(new_text, "\f")
        write_proc_file("text-document/add-temp-back-color", string.format("%d\f%d\f%s", new_selection[1], new_selection[2], color))
    end
end

function onMainChanged()
    onLineChanged()
end
