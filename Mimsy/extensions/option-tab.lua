-- Intercept option-tab (and shift-option-tab) and select the next (or previous) identifier.

mimsy:set_extension_name("option-tab")
mimsy:set_extension_version("1.0")
mimsy:watch_file(1.0, "/mimsy/keydown/text-editor/key/tab/modifiers", "onTabKey")

function onTabKey()
end
