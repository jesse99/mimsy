-- Adds a context menu item to directory windows to duplicate the selected files.
function init(script_dir)
	mimsy:set_extension_name("duplicate-file")
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
		write_proc_file("directory/menu-content", "Duplicate File\nduplicate-file")
	end
end

function findDstPath(root)
    local candidate = root .. " Copy"
    if not fileExists(candidate) then
        return candidate
    end

    for i = 2, 20 do
        candidate = string.format("%s Copy %d", root, i)
        if not fileExists(candidate) then
            return candidate
        end
    end

    return nil
end

function onMenuAction()
    local elements = read_proc_file("directory/menu-action")
    local lines = split(elements, "\n")
    if lines[1] == "duplicate-file" then
        local files = split(lines[2], "\f")
        for i, file in ipairs(files) do
            local dst = findDstPath(file)
            if dst ~= nil then
                local commandLine = string.format("%s\f%s", file, dst)
                local procFile = string.format("file-manager/copy/%s", to_base64(commandLine))
                local text = read_proc_file(procFile)
                local result = split(text, "\f")
                if result[1] ~= "0" then
                    log("Failed to copy '", file, "': ", result[2])
                    write_proc_file("beep", "1")
                end
            else
                log("Couldn't find a file name to copy with using ", file)
                write_proc_file("beep", "1")
            end
        end
    end
end

