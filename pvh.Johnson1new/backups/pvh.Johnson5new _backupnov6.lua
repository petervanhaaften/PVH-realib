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

p.pitch = {}

--will hold data from text file values
p.refdat = {}

--global variable holds menu item preset selection
current_item = 0
--global boolean to hold gui preset menu switcher logic ctl
has_talked = true
-------------------------------
-- FUNCTIONS
-------------------------------
function makenoteBuffer()
   --Msg("testing" .. p.johnsonseq_origin_final)
   --NEED TO iterate over p.johnsonseq_origin_final string, drop each element into a table with a numeric key
   --numeric key corresponds to each note in selection, then you gotta compare each val at each key
   --to each val for each key in refdat, and change note pitch to that value (from refdat).

   --create table to hold iterated string, each cell is one character of final computer origin
   --Msg("jonsonseq_origin_final : " .. p.johnsonseq_origin_final)
   local johnsonStr = p.johnsonseq_origin_final
   --loop to create iterated table
   for i = 0, #johnsonStr do
      local c = johnsonStr:sub(i,i)
      p.johnsonseq_iterated[i] = c
   end


   --create table to hold final pitch value based on refdata and computed origin
   for i = 1, #johnsonStr do
      --Msg("#Johnstr : " .. #johnsonStr)
      --Msg("p.pitch : " .. p.pitch[i-1])
      --collect value for specific note from computed origin
      c = p.johnsonseq_iterated[i] + 1
      --collect associated line in p.pitch
      --Msg("c : " .. c)
      --d = p.pitch[i]
      --replace each value in computed origin with the associated line in p.refdata
      p.johnsonseq_iterated[i] = p.pitch[c-1]
      --Msg(p.johnsonseq_iterated[i])
   end

   --actually transform the midi pitches to values in p.johnsonseq_iterated[i]
   for i=0, notes-1 do --loops through all notes in take
      --fill variables with data from each note
      pitchNew = p.johnsonseq_iterated[i+1] --convert i to string
      local retval, sel, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i) 
      if sel == true then -- find which notes are selected
	   p.origstartppq[i] = startppq --fill table with startppq values at each note index
	   p.origendppq[i] = endppq --fill table wiuth endppq values at each note index
	   --reaper.MIDI_InsertNote(take, sel, muted, p.origstartppq[i], p.origendppq[i], chan, pitchNew, vel, false)
      reaper.MIDI_InsertNote(take, sel, muted, p.origstartppq[i], p.origendppq[i], chan, pitchNew, vel, false)   
      end
      --delete eacg original pitch
      reaper.MIDI_DeleteNote(take, i) 
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
	 reaper.MIDI_InsertNote(take, sel, muted, p.origstartppq[i], p.origendppq[i], chan, p.pitch[i], vel, false)
      end
      --delete each original pitch
      reaper.MIDI_DeleteNote(take, i) 
      i=i+1
   end
end


function builtPitchTable()
	p.pitch[0] = tonumber(pitch0)
	p.pitch[1] = tonumber(pitch1)
	p.pitch[2] = tonumber(pitch2)
	p.pitch[3] = tonumber(pitch3)
	p.pitch[4] = tonumber(pitch4)
	p.pitch[5] = tonumber(pitch5)
	p.pitch[6] = tonumber(pitch6)
	p.pitch[7] = tonumber(pitch7)
end


function johnsonBuffer()
   --builtPitchTable()
   --[[
   p.pitch[0] = tonumber(pitch0)
   p.pitch[1] = tonumber(pitch1)
   p.pitch[2] = tonumber(pitch2)
   p.pitch[3] = tonumber(pitch3)
   p.pitch[4] = tonumber(pitch4)
   p.pitch[5] = tonumber(pitch5)
   p.pitch[6] = tonumber(pitch6)
   p.pitch[7] = tonumber(pitch7)
   ]]--
   for j=0, 7 do
      p.johnsonseq[j] = {}
   end
   --read gui values
   --only check guival for origin on first run
   if p.origin_touch == 0 then
      p.johnsonseq_origin = origin
      Msg("test origin_touch : " .. tostring(p.johnsonseq_origin))
   else end
   p.johnsonseq_new[0] = seq0
   p.johnsonseq_new[1] = seq1
   p.johnsonseq_new[2] = seq2
   p.johnsonseq_new[3] = seq3
   p.johnsonseq_new[4] = seq4
   p.johnsonseq_new[5] = seq5
   p.johnsonseq_new[6] = seq6
   p.johnsonseq_new[7] = seq7
   --split origin into table
   p.johnsonseq_origin_new = {}
   Msg("p.johnsonseq_origin : " .. p.johnsonseq_origin)
   Msg("#p.johnsonseq_origin1 : " .. p.johnsonseq_origin)
   for i = 1, #p.johnsonseq_origin do
      --writing each element into new origin table, from original origin string
      --STACK OVERFLOW APPEARS HERE--
      Msg("#p.johnsonseq_origin2 : " .. tonumber(#p.johnsonseq_origin))
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
   --
   -- printout  to console
   --
   --Msg("origin sequence : " .. p.johnsonseq_origin_final)
   --check to see how long sequence is, and if process should continue
   --Msg("numnotes : " .. notes)
   p.johnsonseq_origin_final_length = string.len(p.johnsonseq_origin_final)
   --Msg("length of origin : " .. p.johnsonseq_origin_final_length)
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

   makenoteBuffer()
   --compareBuffers()
   
end

function makeButton()
   builtPitchTable()
   --when gui 'make' button is pressed. . . 
   getselectedNotes()
   --makenoteBuffer()
   --compareBuffers()
   p.origin_touch = 0
   johnsonBuffer()
end

function menuPresets()

end
-------------------------------
-- GUI
-------------------------------

local ctx = reaper.ImGui_CreateContext('pvh.johnson1')

function loop()
   local visible, open = reaper.ImGui_Begin(ctx, 'pvh.johnson1', true)
   if visible then
   --set window dimensions
      reaper.ImGui_SetWindowSize(ctx, 275, 265, nil)
      --
      -- text inputs for origin
      --
      retval, origin = reaper.ImGui_InputText(ctx, "origin", origin, nil)
 
      --
      -- text inputs seq and pitch, with table columning
      --
      if reaper.ImGui_BeginTable(ctx, 'table1', 2, nil) then
         reaper.ImGui_TableNextRow(ctx)
         reaper.ImGui_TableSetColumnIndex(ctx, 0)
         retval, seq0 = reaper.ImGui_InputText(ctx, "seq0", seq0, nil)
         reaper.ImGui_TableSetColumnIndex(ctx, 1)
         retval, pitch0 = reaper.ImGui_InputText(ctx, "pitch0", pitch0, nil)
         
         reaper.ImGui_TableNextRow(ctx)
         reaper.ImGui_TableSetColumnIndex(ctx, 0)
         retval, seq1 = reaper.ImGui_InputText(ctx, "seq1", seq1, nil)
         reaper.ImGui_TableSetColumnIndex(ctx, 1)
         retval, pitch1 = reaper.ImGui_InputText(ctx, "pitch1", pitch1, nil)
         
         reaper.ImGui_TableNextRow(ctx)
         reaper.ImGui_TableSetColumnIndex(ctx, 0)
         retval, seq2 = reaper.ImGui_InputText(ctx, "seq2", seq2, nil)
         reaper.ImGui_TableSetColumnIndex(ctx, 1)
         retval, pitch2 = reaper.ImGui_InputText(ctx, "pitch2", pitch2, nil)
         
         reaper.ImGui_TableNextRow(ctx)
         reaper.ImGui_TableSetColumnIndex(ctx, 0)
         retval, seq3 = reaper.ImGui_InputText(ctx, "seq3", seq3, nil)
         reaper.ImGui_TableSetColumnIndex(ctx, 1)
         retval, pitch3 = reaper.ImGui_InputText(ctx, "pitch3", pitch3, nil)
         
         reaper.ImGui_TableNextRow(ctx)
         reaper.ImGui_TableSetColumnIndex(ctx, 0)
         retval, seq4 = reaper.ImGui_InputText(ctx, "seq4", seq4, nil)
         reaper.ImGui_TableSetColumnIndex(ctx, 1)
         retval, pitch4 = reaper.ImGui_InputText(ctx, "pitch4", pitch4, nil)
         
         reaper.ImGui_TableNextRow(ctx)
         reaper.ImGui_TableSetColumnIndex(ctx, 0)
         retval, seq5 = reaper.ImGui_InputText(ctx, "seq5", seq5, nil)
         reaper.ImGui_TableSetColumnIndex(ctx, 1)
         retval, pitch5 = reaper.ImGui_InputText(ctx, "pitch5", pitch5, nil)
         
         reaper.ImGui_TableNextRow(ctx)
         reaper.ImGui_TableSetColumnIndex(ctx, 0)
         retval, seq6 = reaper.ImGui_InputText(ctx, "seq6", seq6, nil)
         reaper.ImGui_TableSetColumnIndex(ctx, 1)
         retval, pitch6 = reaper.ImGui_InputText(ctx, "pitch6", pitch6, nil)
         
         reaper.ImGui_TableNextRow(ctx)
         reaper.ImGui_TableSetColumnIndex(ctx, 0)
         retval, seq7 = reaper.ImGui_InputText(ctx, "seq7", seq7, nil)
         reaper.ImGui_TableSetColumnIndex(ctx, 1)
         retval, pitch7 = reaper.ImGui_InputText(ctx, "pitch7", pitch7, nil)
      reaper.ImGui_EndTable(ctx)
      end
      --
      -- pitch preset menu
      --
      local items = "Init\31Major\31Minor\31Lydian\31"
      retval, current_item = reaper.ImGui_Combo(ctx, label, current_item, items, -1)
      --menu logic
      --has_talked = false
      has_talked = reaper.ImGui_IsItemEdited(ctx)
      if has_talked == true then
         if current_item == 0 then
            presetInit()
         elseif current_item == 1 then
            presetMajor()
         elseif current_item == 2 then
            presetMinor()
         elseif current_item == 3 then
            presetLydian()
         end
      end
      --process button
      reaper.ImGui_SameLine(ctx, nil, nil)
      if reaper.ImGui_Button(ctx, 'process', 75, nil) then 
      makeButton()
      end
      reaper.ImGui_End(ctx)
   end
   if open then
      reaper.defer(loop)
   else
      reaper.ImGui_DestroyContext(ctx)
   end
end

reaper.defer(loop)

-------------------------------
-- PRESETS
-------------------------------
--
-- LAUNCH STATE
--
origin = "0"
seq0 = "01"
seq1 = "0"
seq2 = "0"
seq3 = "0"
seq4 = "0"
seq5 = "0"
seq6 = "0"
seq7 = "0"
seq8 = "0"
pitch0 = "0"
pitch1 = "0"
pitch2 = "0"
pitch3 = "0"
pitch4 = "0"
pitch5 = "0"
pitch6 = "0"
pitch7 = "0"

--
-- Init
--

function presetInit()
   pitch0 = "0"
   pitch1 = "0"
   pitch2 = "0"
   pitch3 = "0"
   pitch4 = "0"
   pitch5 = "0"
   pitch6 = "0"
   pitch7 = "0"
end
--
-- Major
--
function presetMajor()
   pitch0 = "60"
   pitch1 = "62"
   pitch2 = "64"
   pitch3 = "65"
   pitch4 = "67"
   pitch5 = "69"
   pitch6 = "71"
   pitch7 = "72"
end

function presetMinor()
   pitch0 = "60"
   pitch1 = "62"
   pitch2 = "63"
   pitch3 = "65"
   pitch4 = "67"
   pitch5 = "68"
   pitch6 = "70"
   pitch7 = "72"
end

function presetLydian()
   pitch0 = "60"
   pitch1 = "62"
   pitch2 = "64"
   pitch3 = "66"
   pitch4 = "67"
   pitch5 = "69"
   pitch6 = "71"
   pitch7 = "73"
end