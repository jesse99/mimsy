-- Adds a context menu item to directory windows to copy the full path of the selected
-- files and directories to the pasteboard.
function init(script_dir)
	mimsy:set_extension_name("copy-path")
	mimsy:set_extension_version("1.0")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/directory/menu-action", "onMenuAction")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/directory/menu-selection", "onMenuSelection")

	assert(dofile(script_dir .. "/helpers.inc.lua"))
    inspect = dofile(script_dir .. "/inspect.inc.lua")
end

function onMenuSelection()
	local elements = read_proc_file("directory/menu-selection")
	local lines = split(elements, "\n")
    local files = split(lines[1], "\f")
	local dirs = split(lines[2], "\f")

    if #files + #dirs == 1 then
		write_proc_file("directory/menu-content", "Copy Path\ncopy-path")
	end
end

function onMenuAction()
    local elements = read_proc_file("directory/menu-action")
    local lines = split(elements, "\n")
    if lines[1] == "copy-path" then
        local files = split(lines[2], "\f")
        copyItems(files)

        local dirs = split(lines[3], "\f")
        copyItems(dirs)
    end
end

function copyItems(items)
    for i, item in ipairs(items) do
        write_proc_file("pasteboard-text", item)
    end
end
