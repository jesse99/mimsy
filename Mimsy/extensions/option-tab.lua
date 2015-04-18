-- Intercept option-tab (and shift-option-tab) and select the next (or previous) identifier.

keys = [==[
{
	"extension": "option-tab",
	"context": "text editor",
	"keys":
	{
		"Command-Option-Tab": "Select the next identifier",
		"Command-Shift-Option-Tab": "Select the previous identifier"
	}
}
]==]

function init(script_dir)
	mimsy:set_extension_name("option-tab")
	mimsy:set_extension_version("1.0")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/keydown/text-editor/option-tab/pressed", "onOptionTab")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/keydown/text-editor/option-shift-tab/pressed", "onOptionShiftTab")

    assert(dofile(script_dir .. "/helpers.inc.lua"))
    inspect = dofile(script_dir .. "/inspect.inc.lua")
	write_proc_file("special-keys", keys)
end

function tab(delta)
	--log("option tabbing")

	local elements = read_proc_file("text-document/element-names")
	--log("elements = ", elements)
	if elements ~= "" then
		local lines = split(elements, "\n")
		local selection_index = lines[1] + 2	-- +2 because lua arrays are 1-based and we skip the first line

		-- lines are formatted as "<element name>\f<location>\f<length>"
		local line = selection_index + delta
		while line >= 1 and line <= #lines do
			local parts = split(lines[line], "\f")
			if parts[1] == "identifier" then
				write_proc_file("text-document/selection-range", string.format("%d\f%d", parts[2], parts[3]))
				break
			end
			line = line + delta
		end

		if line > #lines then
            log("option tab line is ", line, " but there are only ", #lines, " lines")
			write_proc_file("beep", "")
		end
    else
        log("no element names in option tab")
	end

    -- We don't return false because the default behavior of option-tab is insert some
    -- weird character that seems to screw up formatting.
	return true
end

function onOptionTab()
	return tab(1)
end

function onOptionShiftTab()
	return tab(-1)
end
