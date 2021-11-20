--[[
reads note data
puts each current note into origin buffer
have another buffer available, new note buffer
pull out each note from origin buffer, change pitch according to same index in new notes buffer
insert new note at same position as origin note
]]--

--[[
johnson additions
needs:
1) function driven processing for unlimited number of sequences
2) gui w/minimum 8 sequences & origin
3) ability to start from sequence position number ?
4) way to visualize/report sequence number at end of midi item ? comment based ??
]]--


function Msg(str)
  reaper.ShowConsoleMsg(tostring(str) .. "\n")
end
-------------------------------
-- GLOBAL VARIABLES
-------------------------------
reaper.ClearConsole();

-- Get window
window = reaper.MIDIEditor_GetActive()

-- Get current take being edited in MIDI Editor
take = reaper.MIDIEditor_GetTake(window)

-- Loop through & count each selected note
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
i = 0
check = 0
notes_selected=0


p = {} -- data holder
p.newnotes = {}
p.origstartppq = {}
p.origendppq = {}

p.johnsonseq = {}
p.johnsonseq_new = {}

-------------------------------
-- FUNCTIONS
-------------------------------
-- table serialization from
-- http://lua-users.org/wiki/TableUtils

function table.val_to_str ( v )
   if "string" == type( v ) then
      v = string.gsub( v, "\n", "\\n" )
      if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
	 return "'" .. v .. "'"
      end
      return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
   else
      return "table" == type( v ) and table.tostring( v ) or
      tostring( v )
   end
end

function table.key_to_str ( k )
   if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
      return k
   else
      return "[" .. table.val_to_str( k ) .. "]"
   end
end

function table.tostring( tbl )
   local result, done = {}, {}
   for k, v in ipairs( tbl ) do
      table.insert( result, table.val_to_str( v ) )
      done[ k ] = true
   end
   for k, v in pairs( tbl ) do
      if not done[ k ] then
	 table.insert( result,
	 table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
      end
   end
   return "{" .. table.concat( result, "," ) .. "}"
end


      --serialize table
      --local value = table.tostring(p.johnsonbuf[0])

-------------------------------
-- FUNCTIONS
-------------------------------
function makenoteBuffer()
   --read GUI values to determine Low & High rand range
   local low = GUI.Val("Low")
   local high = GUI.Val("High")
   local randomMax = math.floor(high - low)
   --  if randomMax is 0, script will crash, so default to 1
   if randomMax == 0 then
      randomMax = 1
   else end
   --builds note buffer of equal numnber elements to selected notes
   for i=0, notes-1 do --loops through all notes in take
      local random = low + math.random(randomMax) --pitch for note
      local retval, sel, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
      if sel == true then -- find which notes are selected
	 p.newnotes[i] = random --fill table with random pitch at each note index
	 p.origstartppq[i] = startppq --fill table with startppq values at each note index
	 p.origendppq[i] = endppq --fill table wiuth endppq values at each note index
      end
      i=i+1
   end
end


function getselectedNotes()
   for i=0, notes-1 do --loops through all notes in take
      --fill variables with data from each note
      local retval, sel, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
      if sel == true then -- find which notes are selected
	 check = check + 1 -- if notes selected add it to check count
      end
      i=i+1
   end
end

function compareBuffers()
   for i=0, notes-1 do --loops through all notes in take
      --fill variables with data from each note
      local retval, sel, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i) 
      if sel == true then -- find which notes are selected
	 reaper.MIDI_InsertNote(take, sel, muted, p.origstartppq[i], p.origendppq[i], chan, p.newnotes[i], vel, false)
      end
      --delete eacg original pitch
      reaper.MIDI_DeleteNote(take, i) 
      i=i+1
   end
end

function johnsonBuffer()
   for j=0, 7 do
      p.johnsonseq[j] = {}
   end
   --predefine sequences
   p.johnsonseq[0] = "100"
   p.johnsonseq[1] = "011"
   --values from GUI or input text file
   p.johnsonseq_new[0] = "11"
   p.johnsonseq_new[1] = "010"
   for j=0, 1 do
      for k=0,1 do
	 p.johnsonseq[j] = string.gsub(p.johnsonseq[j], k, p.johnsonseq_new[j])
      end
      Msg(p.johnsonseq[j])

   end
   
   for i=0, notes-1 do --loops through all notes in take
      --local random = low + math.random(randomMax) --pitch for note
      local retval, sel, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
      if sel == true then -- find which notes are selected
	 p.newnotes[i] = random --fill table with random pitch at each note index
	 p.origstartppq[i] = startppq --fill table with startppq values at each note index
	 p.origendppq[i] = endppq --fill table wiuth endppq values at each note index
      end
      i=i+1
   end
   --Msg(p.johnsonbuf)
end

function makeButton()
   --when gui 'make' button is pressed. . . 
   getselectedNotes()
   makenoteBuffer()
   compareBuffers()
end

-------------------------------
-- GUI
-------------------------------

local lib_path = reaper.GetExtState("Lokasenna_GUI", "lib_path_v2")
if not lib_path or lib_path == "" then
    reaper.MB("Couldn't load the Lokasenna_GUI library. Please run 'Set Lokasenna_GUI v2 library path.lua' in the Lokasenna_GUI folder.", "Whoops!", 0)
    return
end
loadfile(lib_path .. "Core.lua")()




GUI.req("Classes/Class - Textbox.lua")()
GUI.req("Classes/Class - Button.lua")()
-- If any of the requested libraries weren't found, abort the script.
if missing_lib then return 0 end

GUI.name = "pvh.Notemod1"
GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, 130, 135
GUI.anchor, GUI.corner = "mouse", "C"

GUI.New("High", "Textbox", {
    z = 11,
    x = 48,
    y = 48,
    w = 40,
    h = 20,
    caption = "High",
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20
})

GUI.New("make", "Button", {
    z = 11,
    x = 48,
    y = 80,
    w = 48,
    h = 24,
    caption = "make",
    font = 3,
    col_txt = "txt",
    col_fill = "elm_frame",
    --MAIN
    func = makeButton
})

GUI.New("Low", "Textbox", {
    z = 11,
    x = 48,
    y = 16,
    w = 40,
    h = 20,
    caption = "Low",
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20
})

GUI.Init()
GUI.Main()

GUI.Val("Low","60")
GUI.Val("High","80")


-------------------------------
-- MAIN
-------------------------------

getselectedNotes()
makenoteBuffer()
compareBuffers()
 johnsonBuffer()
