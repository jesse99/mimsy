-- Adds a context menu item to directory windows to create a new directory.
function init(script_dir)
	mimsy:set_extension_name("new-directory")
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

    if #files > 0 then
		write_proc_file("directory/menu-content", "Add New Directory\nnew-directory")
	end
end

function findDstPath(root)
    local candidate = root .. "/New Directory"
    if not fileExists(candidate) then
        return candidate
    end

    for i = 2, 20 do
        candidate = string.format("%s/New Directory %d", root, i)
        if not fileExists(candidate) then
            return candidate
        end
    end

    return nil
end

function onMenuAction()
    local elements = read_proc_file("directory/menu-action")
    local lines = split(elements, "\n")
    if lines[1] == "new-directory" then
        local files = split(lines[2], "\f")
        for i, file in ipairs(files) do
            local dst = findDstPath(directory_path(file))
            if dst ~= nil then
                local procFile = string.format("file-manager/new-directory/%s", to_base64(dst))
                local text = read_proc_file(procFile)
                local result = split(text, "\f")
                if result[1] ~= "0" then
                    log("Failed to create '", dst, "': ", result[2])
                    write_proc_file("beep", "1")
                end
            else
                log("Couldn't find a directory name to create using ", file)
                write_proc_file("beep", "1")
            end
        end
    end
end

