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

    if id == nil then
        local procFile = string.format("actions/add-menu-item/%s", to_base64("text view\ftoggle-trailing-whitespace"))
        id = read_proc_file(procFile)
        setTitle("Show Trailing Whitespace")
    end
end

function show()
    local key = "show-trailing-whitespace"
    local pattern = [[\S+([\ \t]+)\n]]
    local style = "Error"
    local chars = "\xE2\x99\xA6"    -- BLACK DIAMOND SUIT in UTF-8
    local repeated = "true"
    write_proc_file("text-document/map-characters", string.format("%s\f%s\f%s\f%s\f%s", key, pattern, style, chars, repeated))
end

function hide()
    local key = "show-trailing-whitespace"
    write_proc_file("text-document/unmap-characters", key)
end

function setTitle(title)
    local args = to_base64(string.format("%s\f%s", id, title))
    local procFile = string.format("actions/set-menu-item-title/%s", args)
    read_proc_file(procFile)
end

function onToggleDisplay()
    local showing = read_proc_file("text-document/key-values/show-trailing-whitespace") == "true"
    showing = not showing

    if showing then
        write_proc_file("text-document/key-values/show-trailing-whitespace", "true")
        setTitle("Hide Trailing Whitespace")
        show()
    else
        write_proc_file("text-document/key-values/show-trailing-whitespace", "false")
        setTitle("Show Trailing Whitespace")
        hide()
    end
end

function onOpened()
    write_proc_file("text-document/key-values/show-trailing-whitespace", "true")
    setTitle("Hide Trailing Whitespace")
    show()
end

function onMainChanged()
    local showing = read_proc_file("text-document/key-values/show-trailing-whitespace") == "true"
    if showing then
        setTitle("Hide Trailing Whitespace")
    else
        setTitle("Show Trailing Whitespace")
    end
end
