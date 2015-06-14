-- Uses a special glyph to show control characters.

function init(script_dir)
	mimsy:set_extension_name("show-control-chars")
	mimsy:set_extension_version("1.0")
	
    assert(dofile(script_dir .. "/helpers.inc.lua"))
    inspect = dofile(script_dir .. "/inspect.inc.lua")
    dofile(script_dir .. "/base64.inc.lua")

    mimsy:watch_file(1.0, "/Volumes/Mimsy/text-document/opened", "onOpened")
    mimsy:watch_file(1.0, "/Volumes/Mimsy/text-document/main-changed", "onMainChanged")
	mimsy:watch_file(1.0, "toggle-control-chars", "onToggleDisplay")

    local installedID = read_proc_file("key-values/show-control-chars-id")
    if #installedID == 0 then
        id = perform_action("add-menu-item", "text view", "Show Control Characters", "toggle-control-chars")[1]
        write_proc_file("key-values/show-control-chars-id", id)
    else
        id = installedID
    end
end

-- Special case all control characters but CR, LF, and HT.
function show()
    local key = "show-control-chars"
    local pattern = "[\\x00-\\x08\\x0b\\x0c\\x0e-\\x1f\\x7f]"
    local style = "Error"
    local chars = "?"
    local repeated = "true"
    write_proc_file("text-document/map-characters", string.format("%s\f%s\f%s\f%s\f%s", key, pattern, style, chars, repeated))
end

function hide()
    local key = "show-control-chars"
    write_proc_file("text-document/unmap-characters", key)
end

function enabled()
    return #read_proc_file("text-document/language") > 0 and read_proc_file("app-settings/ShowControlChars") == "true"
end

function onToggleDisplay()
    local showing = read_proc_file("text-document/key-values/show-control-chars") == "true"
    showing = not showing

    if showing then
        write_proc_file("text-document/key-values/show-control-chars", "true")
        perform_action("set-menu-item-title", "Hide Control Characters", title)
        show()
    else
        write_proc_file("text-document/key-values/show-control-chars", "false")
        perform_action("set-menu-item-title", id, "Show Control Characters")
        hide()
    end
end

function onOpened()
    if enabled() then
        write_proc_file("text-document/key-values/show-control-chars", "true")
    end
end

function onMainChanged()
    if enabled() then
        local showing = read_proc_file("text-document/key-values/show-control-chars") == "true"
        if showing then
            perform_action("set-menu-item-title", id, "Hide Control Characters")
        else
            perform_action("set-menu-item-title", id, "Show Control Characters")
        end
        perform_action("enable-menu-item", id)
        show()
    else
        perform_action("set-menu-item-title", id, "Show Control Characters")
        perform_action("disable-menu-item", id)
        hide()
    end
end
