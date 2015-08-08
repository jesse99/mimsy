-- Intercept command-control-up-arrow and command-control-down-arrow and open the dual of
-- the current file (e.g. if a *.h file is open then open the associated *.c file and vice
-- versa). The file to open is taken from the FileDual setting.

keys = [==[
{
    "extension": "open-dual",
    "context": "text editor",
    "keys":
    {
        "Command-Control-Up-Arrow": "Open the file associated with the current text file",
        "Command-Control-Down-Arrow": "Open the file associated with the current text file"
    }
}
]==]

function init(script_dir)
    mimsy:set_extension_name("open-dual")
    mimsy:set_extension_version("1.0")
    mimsy:watch_file(1.0, "/Volumes/Mimsy/keydown/text-editor/command-control-up-arrow/pressed", "onArrow")
    mimsy:watch_file(1.0, "/Volumes/Mimsy/keydown/text-editor/command-control-down-arrow/pressed", "onArrow")

    assert(dofile(script_dir .. "/helpers.inc.lua"))
    inspect = dofile(script_dir .. "/inspect.inc.lua")
    dofile(script_dir .. "/base64.inc.lua")
    write_proc_file("special-keys", keys)
end

function findNewExtensions(oldExt)
    local settings = read_proc_file("text-document/settings/FileDual")
    settings = split(settings, "\f")
    for i, entry in ipairs(settings) do
        local extensions = split(entry, " +")
        if extensions[1] == oldExt then
            table.remove(extensions, 1)
            return extensions
        end
    end

    return nil
end

function onArrow()
    local handled = false

    local path = read_proc_file("text-document/path")
    local oldExt = file_extension(path)
    if oldExt ~= nil then
        local extensions = findNewExtensions(oldExt)
        if extensions ~= nil then
            -- We use the file name instead of the path because headers are often in a different
            -- directory than source files.
            local baseName = file_name(path)
            baseName = string.sub(baseName, 1, string.len(baseName) - string.len(oldExt))
            for i, newExt in ipairs(extensions) do
                local fileName = baseName .. newExt

                local procFile = string.format("actions/open-local/%s", to_base64(fileName))
                _= read_proc_file(procFile)

                handled = true
            end
        end
    end

    return handled
end
