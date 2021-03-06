-- Script generated by Lokasenna's GUI Builder


local lib_path = reaper.GetExtState("Lokasenna_GUI", "lib_path_v2")
if not lib_path or lib_path == "" then
    reaper.MB("Couldn't load the Lokasenna_GUI library. Please run 'Set Lokasenna_GUI v2 library path.lua' in the Lokasenna_GUI folder.", "Whoops!", 0)
    return
end
loadfile(lib_path .. "Core.lua")()




GUI.req("Classes/Class - Button.lua")()
GUI.req("Classes/Class - Textbox.lua")()
-- If any of the requested libraries weren't found, abort the script.
if missing_lib then return 0 end



GUI.name = "pvh.euclid"
GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, 150, 165
GUI.anchor, GUI.corner = "mouse", "C"

function test()
 end

GUI.New("make", "Button", {
    z = 11,
    x = 64.0,
    y = 112.0,
    w = 48,
    h = 24,
    caption = "make",
    font = 3,
    col_txt = "txt",
    col_fill = "elm_frame",
    func = Euclidiser
})

GUI.New("Pulses", "Textbox", {
    z = 11,
    x = 64.0,
    y = 16.0,
    w = 40,
    h = 20,
    caption = "Pulses",
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20,
    pulseVal = Pulses
})

GUI.New("Steps", "Textbox", {
    z = 11,
    x = 64,
    y = 48,
    w = 40,
    h = 20,
    caption = "Steps",
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20,
    --edit
    stepVal = Steps
})

GUI.New("Rotation", "Textbox", {
    z = 11,
    x = 64,
    y = 80,
    w = 40,
    h = 20,
    caption = "Rotation",
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20,
    --edit
    rotVal = Rotation
})







GUI.Init()
GUI.Main()
