-- Adds a context menu item to directory windows to create a new blank file.
function init(script_dir)
	mimsy:set_extension_name("new-file")
	mimsy:set_extension_version("1.0")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/directory/menu-action", "onMenuAction")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/directory/menu-selection", "onMenuSelection")

	assert(dofile(script_dir .. "/helpers.inc.lua"))
    inspect = dofile(script_dir .. "/inspect.inc.lua")
end

function selection_root(files, dirs)
	local root = nil

	for index, file in pairs(files) do
		local dir = directory_path(file)
		if root == nil then
			root = dir
		elseif root ~= dir then
			return nil
		end
	end

	for index, dir in pairs(dirs) do
		if root == nil then
			root = dir
		elseif root ~= dir then
			return nil
		end
	end
	
	return root
end

function onMenuSelection()
	local elements = read_proc_file("directory/menu-selection")
	local lines = split(elements, "\n")
	local files = split(lines[1], "\f")
	local dirs = split(lines[2], "\f")

    local root = selection_root(files, dirs)
	if root ~= nil then
		write_proc_file("directory/menu-content", "Add New File\nnew-file")
	end
end

function findFilePath(root)
    local candidate = root .. "/New File"
    if not fileExists(candidate) then
        return candidate
    end

    for i = 2, 20 do
        candidate = string.format("%s/New File %d", root, i)
        if not fileExists(candidate) then
            return candidate
        end
    end

    return nil
end

function onMenuAction()
    local elements = read_proc_file("directory/menu-action")
    local lines = split(elements, "\n")
    if lines[1] == "new-file" then
        local files = split(lines[2], "\f")
        local dirs = split(lines[3], "\f")
        local root = selection_root(files, dirs)

        local path = findFilePath(root)
        if path ~= nil then
            local file, err = io.open(path, "w")
            if file ~= nil then
                file:write("")
                io.close(file)
            else
                log("Failed to open '", file, "': ", err)
                write_proc_file("beep", "1")
            end
        else
            log("Couldn't find a file name to use under ", root)
            write_proc_file("beep", "1")
        end
    end
end

