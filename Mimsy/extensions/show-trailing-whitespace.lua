-- Uses a special glyph to show trailing whitespace.

function init(script_dir)
	mimsy:set_extension_name("show-trailing-whitespace")
	mimsy:set_extension_version("1.0")
	
    assert(dofile(script_dir .. "/helpers.inc.lua"))
    inspect = dofile(script_dir .. "/inspect.inc.lua")
    dofile(script_dir .. "/base64.inc.lua")

    mimsy:watch_file(1.0, "/Volumes/Mimsy/text-document/opened", "onOpened")
    mimsy:watch_file(1.0, "/Volumes/Mimsy/text-document/main-changed", "onMainChanged")
	mimsy:watch_file(1.0, "toggle-trailing-whitespace", "onToggleDisplay")

    local installedID = read_proc_file("key-values/show-trailing-whitespace-id")
    if #installedID == 0 then
        id = perform_action("add-menu-item", "text view", "Show Trailing Whitespace", "toggle-trailing-whitespace")[1]
        write_proc_file("key-values/show-trailing-whitespace-id", id)
    else
        id = installedID
    end
end

function show()
    local key = "show-trailing-whitespace"
    local pattern = [[\S+([\ \t]+)\n]]
    local style = "Error"
    local chars = "\xE2\x99\xA6"    -- BLACK DIAMOND SUIT encoded as UTF-8
    local repeated = "true"
    write_proc_file("text-document/map-characters", string.format("%s\f%s\f%s\f%s\f%s", key, pattern, style, chars, repeated))
end

function hide()
    local key = "show-trailing-whitespace"
    write_proc_file("text-document/unmap-characters", key)
end

function enabled()
    return #read_proc_file("text-document/language") > 0 and read_proc_file("app-settings/ShowTrailingWhiteSpace") == "true"
end

function onToggleDisplay()
    local showing = read_proc_file("text-document/key-values/show-trailing-whitespace") == "true"
    showing = not showing

    if showing then
        write_proc_file("text-document/key-values/show-trailing-whitespace", "true")
        perform_action("set-menu-item-title", "Hide Trailing Whitespace", title)
        show()
    else
        write_proc_file("text-document/key-values/show-trailing-whitespace", "false")
        perform_action("set-menu-item-title", id, "Show Trailing Whitespace")
        hide()
    end
end

function onOpened()
    if enabled() then
        write_proc_file("text-document/key-values/show-trailing-whitespace", "true")
    end
end

function onMainChanged()
    if enabled() then
        local showing = read_proc_file("text-document/key-values/show-trailing-whitespace") == "true"
        if showing then
            perform_action("set-menu-item-title", id, "Hide Trailing Whitespace")
        else
            perform_action("set-menu-item-title", id, "Show Trailing Whitespace")
        end
        perform_action("enable-menu-item", id)
        show()
    else
        perform_action("set-menu-item-title", id, "Show Trailing Whitespace")
        perform_action("disable-menu-item", id)
        hide()
    end
end
