-- Adds a context menu item to directory windows to move the selected files and directories to the trash.
function init(script_dir)
	mimsy:set_extension_name("trash-item")
	mimsy:set_extension_version("1.0")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/directory/menu-action", "onMenuAction")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/directory/menu-selection", "onMenuSelection")

	assert(dofile(script_dir .. "/helpers.inc.lua"))
    inspect = dofile(script_dir .. "/inspect.inc.lua")
    dofile(script_dir .. "/base64.inc.lua")
end

function onMenuSelection()
	local elements = read_proc_file("directory/menu-selection")
	local lines = split(elements, "\n")
    local files = split(lines[1], "\f")
	local dirs = split(lines[2], "\f")

    if #files > 0 or #dirs > 0 then
		write_proc_file("directory/menu-content", "Move to Trash\ntrash-item")
	end
end

function onMenuAction()
    local elements = read_proc_file("directory/menu-action")
    local lines = split(elements, "\n")
    if lines[1] == "trash-item" then
        local files = split(lines[2], "\f")
        trashItems(files)

        local dirs = split(lines[3], "\f")
        trashItems(dirs)
    end
end

function trashItems(items)
    for i, item in ipairs(items) do
        local procFile = string.format("actions/trash/%s", to_base64(item))
        local text = read_proc_file(procFile)
        local result = split(text, "\f")
        if result[1] ~= "0" then
            log("Failed to trash '", item, "': ", result[2])
            write_proc_file("beep", "1")
        end
    end
end

