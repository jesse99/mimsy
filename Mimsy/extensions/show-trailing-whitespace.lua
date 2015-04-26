-- Use a special glyph to show trailing whitespace.

function init(script_dir)
	mimsy:set_extension_name("show-trailing-whitespace")
	mimsy:set_extension_version("1.0")
	
	-- Temporary attributes are a bit annoying because they don't affect the typing attributes
	-- so edits don't look right. It'd be possible to use normal attributes but then we'd have
	-- to somehow remove them before saving and copying. So, for now, we just re-apply the line
	-- highlighting after normal styles are applied to fix the line up.
	mimsy:watch_file(1.0, "/Volumes/Mimsy/text-document/opened", "onOpened")

    assert(dofile(script_dir .. "/helpers.inc.lua"))
    inspect = dofile(script_dir .. "/inspect.inc.lua")
end

function onOpened()
    local key = "show-trailing-whitespace"
    local pattern = [[\S+([\ \t]+)\n]]
    local style = "Error"
    local chars = "\xE2\x99\xA6"    -- BLACK DIAMOND SUIT in UTF-8
    local repeated = "true"
    write_proc_file("text-document/map-characters", string.format("%s\f%s\f%s\f%s\f%s", key, pattern, style, chars, repeated))
end
