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

p.johnsonseq_iterated = {}

--will hold data from text file values
p.refdat = {}
-------------------------------
-- DEBUG FUNCTIONS
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
   --Msg("testing" .. p.johnsonseq_origin_final)
   --NEED TO iterate over p.johnsonseq_origin_final string, drop each element into a table with a numeric key
   --numeric key corresponds to each note in selection, then you gotta compare each val at each key
   --to each val for each key in refdat, and change note pitch to that value (from refdat).

   --create table to hold iterated string, each cell is one character of final computer origin

   local johnsonStr = p.johnsonseq_origin_final
   --loop to create iterated table
   for i = 1, #johnsonStr do
      local c = johnsonStr:sub(i,i)
      p.johnsonseq_iterated[i] = c
   end


   --create table to hold final pitch value based on refdata and computed origin
   for i = 1, #johnsonStr do
      --collect value for specific note from computed origin
      c = p.johnsonseq_iterated[i] + 1
      --collect associated line in p.refdat
      d = p.refdat[c]
      --replace each value in computed origin with the associated line in p.refdata
      p.johnsonseq_iterated[i] = d
      --Msg(p.johnsonseq_iterated[i])
   end


   --actually transform the midi pitches to values in p.johnsonseq_iterated[i]
   for i=0, notes-1 do --loops through all notes in take
      --fill variables with data from each note
      pitchNew = tostring(p.johnsonseq_iterated[i+1]) --convert i to string

      local retval, sel, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i) 
      if sel == true then -- find which notes are selected
	 p.origstartppq[i] = startppq --fill table with startppq values at each note index
	 p.origendppq[i] = endppq --fill table wiuth endppq values at each note index
	 reaper.MIDI_InsertNote(take, sel, muted, p.origstartppq[i], p.origendppq[i], chan, pitchNew, vel, false)
      end
      --delete eacg original pitch
      reaper.MIDI_DeleteNote(take, i) 
      i=i+1
   end
   
end

function readRefdat()
   --[[
   read through the referall database, which contains a line indicating
   the value for each referred number in the origin & transformed origin
   ]]--
   file = assert(io.open("/Users/pvh/src/PVH-realib/pvh.Johnson1/refer_example1.txt", r))
   
   -- main loop reads through txt file.
   local i = 1
   
   for line in file:lines() do
      p.refdat[i]=line
      i=i+1
   end
   --printy = table.key_to_str (3. )
   --printx = table.tostring(p.refdat)
   --printy = table.val_to_string(3)
   --Msg(printx)
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
	 reaper.MIDI_InsertNote(take, sel, muted, p.origstartppq[i], p.origendppq[i], chan, p.refdata[i], vel, false)
      end
      --delete eacg original pitch
      reaper.MIDI_DeleteNote(take, i) 
      i=i+1
   end
end

function johnsonBuffer()
   
   readRefdat()
   
   for j=0, 7 do
      p.johnsonseq[j] = {}
   end
   --read gui values
   --only check guival for origin on first run
   if p.origin_touch == 0 then
      p.johnsonseq_origin = GUI.Val("origin")
   else end
   p.johnsonseq_new[0] = GUI.Val("seq0")
   p.johnsonseq_new[1] = GUI.Val("seq1")
   p.johnsonseq_new[2] = GUI.Val("seq2")
   p.johnsonseq_new[3] = GUI.Val("seq3")
   p.johnsonseq_new[4] = GUI.Val("seq4")
   p.johnsonseq_new[5] = GUI.Val("seq5")
   p.johnsonseq_new[6] = GUI.Val("seq6")
   p.johnsonseq_new[7] = GUI.Val("seq7")
   --split origin into table
   p.johnsonseq_origin_new = {}
   for i = 1, #p.johnsonseq_origin do
      --writing each element into new origin table, from original origin string
      p.johnsonseq_origin_new[i] = p.johnsonseq_origin:sub(i, i)
   end
   --build table with indexes to be replaced
   -- & replace values ???
   p.johnsonseq_index = {}
   for j = 0, 7 do
      for k,v in pairs(p.johnsonseq_origin_new) do
	 jStr = tostring(j) --convert j to string
	 if v == jStr then
	    --replace each cell in origin table with appropriate cell in new sequence table
	    p.johnsonseq_origin_new[k] = p.johnsonseq_new[j]
	 end
      end
      j = j+1
   end
   --concatenate transformed origin table
   p.johnsonseq_origin_final = table.concat(p.johnsonseq_origin_new)
   Msg(p.johnsonseq_origin_final)
   --check to see how long sequence is, and if process should continue
   Msg("numnotes : " .. notes)
   p.johnsonseq_origin_final_length = string.len(p.johnsonseq_origin_final)
   Msg("length of origin : " .. p.johnsonseq_origin_final_length)



   
   --add take "name" (label) of number of notes
   local newname = notes .. "notes" --new label string
   local item  = reaper.GetSelectedMediaItem(0, 0)
   local take = reaper.GetActiveTake(item)
   reaper.ULT_SetMediaItemNote(item, name)
   retval, stringNeedBig = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", newname, 1)

   --if final origin length is less than number of selected notes, run process again, else end.
   if p.johnsonseq_origin_final_length < notes then
      --move final transformed origin into original origin, for further processing
      p.johnsonseq_origin = p.johnsonseq_origin_final
      --reprocess, until origin_final has same or more num of elements as selected notes
      p.origin_touch = 1 --don't let GUI touch origin variable !
      --allow start position change (start on nth element in p.johnsonseq_origin_final
      johnsonBuffer()
   else end

   --get midi number from p.refdat
   --printx3 = p.refdat(1)
   -- Msg(printx3)
  -- getselectedNotes()
   makenoteBuffer()
   --compareBuffers()
   
end

function makeButton()
   --when gui 'make' button is pressed. . . 
   getselectedNotes()
   --makenoteBuffer()
   --compareBuffers()
   p.origin_touch = 0
   johnsonBuffer()
end

-------------------------------
-- GUI
-------------------------------
-- Script generated by Lokasenna's GUI Builder


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



GUI.name = "pvh.johnsontransform1"
GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, 215, 335
GUI.anchor, GUI.corner = "mouse", "C"



GUI.New("make", "Button", {
    z = 11,
    x = 48,
    y = 304,
    w = 48,
    h = 24,
    caption = "make",
    font = 3,
    col_txt = "txt",
    col_fill = "elm_frame",
    func = makeButton
})
GUI.New("seq2", "Textbox", {
    z = 11,
    x = 48,
    y = 112,
    w = 148,
    h = 20,
    caption = "seq2",
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20
})

GUI.New("seq3", "Textbox", {
    z = 11,
    x = 48,
    y = 144,
    w = 148,
    h = 20,
    caption = "seq3",
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20
})

GUI.New("seq6", "Textbox", {
    z = 11,
    x = 48,
    y = 240,
    w = 148,
    h = 20,
    caption = "seq6",
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20
})

GUI.New("seq7", "Textbox", {
    z = 11,
    x = 48,
    y = 272,
    w = 148,
    h = 20,
    caption = "seq7",
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20
})

GUI.New("seq4", "Textbox", {
    z = 11,
    x = 48,
    y = 176,
    w = 148,
    h = 20,
    caption = "seq4",
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20
})

GUI.New("seq5", "Textbox", {
    z = 11,
    x = 48,
    y = 208,
    w = 148,
    h = 20,
    caption = "seq5",
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20
})

GUI.New("seq0", "Textbox", {
    z = 11,
    x = 48,
    y = 48,
    w = 148,
    h = 20,
    caption = "seq0",
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20
})

GUI.New("origin", "Textbox", {
    z = 11,
    x = 48,
    y = 16,
    w = 148,
    h = 20,
    caption = "origin",
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20
})

GUI.New("seq1", "Textbox", {
    z = 11,
    x = 48,
    y = 80,
    w = 148,
    h = 20,
    caption = "seq1",
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


GUI.Val("origin","01101")
GUI.Val("seq0","100")
GUI.Val("seq1","010")


-------------------------------
-- MAIN
-------------------------------

--getselectedNotes()
--makenoteBuffer()
--compareBuffers()
--johnsonBuffer()
