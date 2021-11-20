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
-- TABLE helpers
-------------------------------
-- dump table helper from:
-- https://stackoverflow.com/questions/9168058/how-to-dump-a-table-to-console
-- Msg("Table:", dump(table))
function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

-- table length helper from:
-- https://stackoverflow.com/questions/2705793/how-to-get-number-of-entries-in-a-lua-table
-- Msg("Table length:", tableLength(table))
function tableLength(T)
   local count = 0
   for _ in pairs(T) do count = count + 1 end
   return count
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
p.pitchTable = {}

--will hold data from text file values
p.refdat = {}

--global variable holds menu item preset selection
current_item = 0
--global boolean to hold gui preset menu switcher logic ctl
has_talked = true
--global variable to check length of global computed result
lengthChecker = false
--global variable holds previous transformed origin length
p.johnsonseq_origin_final_length_archive = 0
--global variable holds current transformed origin length
p.johnsonseq_origin_final = {}
p.johnsonseq_origin_new = {}
--base gui entry values for octave/pitch offset
pitchBase = 0
octaveBase = 0
octaveSize = 0
--test if notes have been transformed, if true then stop to avoid multiple runs
notesTransformed = false  
-------------------------------
-- FUNCTIONS
-------------------------------
function makenoteBuffer()  
   --NEED TO iterate over p.johnsonseq_origin_final string, drop each element into a table with a numeric key
   --numeric key corresponds to each note in selection, then you gotta compare each val at each key
   --to each val for each key in refdat, and change note pitch to that value (from refdat).
   --create table to hold iterated string, each cell is one character of final computer origin
   local johnsonStr = p.johnsonseq_origin_final
   --loop to create iterated table
   for i = 0, #johnsonStr do
      local c = johnsonStr:sub(i,i)
      p.johnsonseq_iterated[i] = c
   end

   --create table to hold final pitch value based on refdata and computed origin
   for i = 1, #johnsonStr do
      --collect value for specific note from computed origin
      c = p.johnsonseq_iterated[i] + 1
      --collect associated line in p.pitch
      --replace each value in computed origin with the associated line in p.refdata
      p.johnsonseq_iterated[i] = p.pitch[c-1]
   end
   
   --actually transform the midi pitches to values in p.johnsonseq_iterated[i]
   -- only run this process if transformed origin is long enough to fill in all note pitches
   for i=0, notes-1 do --loops through all notes in take
      -- git pitchNew
      octaveNew = p.johnsonseq_iterated[i+1] 
      --fill variables with data from each note
      local retval, sel, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i) 
      if sel == true then -- find which notes are selected
      p.origstartppq[i] = startppq --fill table with startppq values at each note index
      p.origendppq[i] = endppq --fill table wiuth endppq values at each note index
      --create new pitch with resulted of transformed octave
      p.pitchTable[i] = pitch + (octaveSize * octaveNew)
      --reaper.MIDI_InsertNote(take, sel, muted, p.origstartppq[i], p.origendppq[i], chan, pitchNew, vel, false)
      reaper.MIDI_InsertNote(take, sel, muted, p.origstartppq[i], p.origendppq[i], chan, p.pitchTable[i], vel, false)   
      end
      --delete eacg original pitch
      reaper.MIDI_DeleteNote(take, i) 
      i=i+1
   end
   --print note with all transformations
   local item = reaper.GetSelectedMediaItem(0, 0) -- Get selected item 0
   local currentNotes = reaper.ULT_GetMediaItemNote(item)
	reaper.ULT_SetMediaItemNote(item, currentNotes .. '\n OCTAVE PROCESS \n ~~~~~~~~~~~~~ \n origin : ' .. origin .. '\n seq0 : ' .. seq0 .. '\n seq1 : ' .. seq1 .. '\n seq2 : ' .. seq2 .. '\n seq3 : ' .. seq3 .. '\n seq4 : ' .. seq4 .. '\n seq5 : ' .. seq5 .. '\n seq6 : ' .. seq6 .. '\n seq7 : ' .. seq7 ..  '\n final transformed sequence : ' .. dump(p.johnsonseq_origin_final))
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
	p.pitch[0] = tonumber(octave0)
	p.pitch[1] = tonumber(octave1)
	p.pitch[2] = tonumber(octave2)
	p.pitch[3] = tonumber(octave3)
	p.pitch[4] = tonumber(octave4)
	p.pitch[5] = tonumber(octave5)
	p.pitch[6] = tonumber(octave6)
	p.pitch[7] = tonumber(octave7)
end

function johnsonBuffer()
   --archive the previous transformed origin length
   p.johnsonseq_origin_final_length_archive = tableLength(p.johnsonseq_origin_new)
   for j=0, 7 do
      p.johnsonseq[j] = {}
   end
   --read gui values
   --only check guival for origin on first run
   if p.origin_touch == 0 then
      p.johnsonseq_origin = origin
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
   for i = 1, #p.johnsonseq_origin do
      --writing each element into new origin table, from original origin string
      p.johnsonseq_origin_new[i] = p.johnsonseq_origin:sub(i, i)
   end
   
   --build table with indexes to be replaced
   -- & replace values ???
   p.johnsonseq_index = {}
   for j = 0, 7 do
      --possible stack overflow
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

   --check to see how long sequence is, and if process should continue
   p.johnsonseq_origin_final_length = string.len(p.johnsonseq_origin_final)
   --p.johnsonseq_origin_final_length = tableLength(p.johnsonseq_origin_new)

   --if final origin length is less than number of selected notes, run process again, else end.
   if p.johnsonseq_origin_final_length < notes and lengthChecker == false then
      p.johnsonseq_origin = p.johnsonseq_origin_final
      --reprocess, until origin_final has same or more num of elements as selected notes
      p.origin_touch = 1 --don't let GUI touch origin variable !
      -- if transformed origin same length as archived (previous) origin, then STOP, or else stack overflow!
      if p.johnsonseq_origin_final_length == p.johnsonseq_origin_final_length_archive then
        lengthChecker = true       
      end    
      --allow start position change (start on nth element in p.johnsonseq_origin_final
      johnsonBuffer()
   else end
   --only do makenotebuffer if orgin transformed is long enough
   if p.johnsonseq_origin_final_length > notes and notesTransformed == false then
      makenoteBuffer()
      notesTransformed = true     
   else end
end

function makeButton()
   notesTransformed = false
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

local ctx = reaper.ImGui_CreateContext('pvh.johnson1_octave')

function loop()
   local visible, open = reaper.ImGui_Begin(ctx, 'pvh.johnson1_octave', true)
   if visible then
   --set window dimensions
      reaper.ImGui_SetWindowSize(ctx, 320, 290, nil)
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
         retval, octave0 = reaper.ImGui_InputText(ctx, "octave0", octave0, nil)
         
         reaper.ImGui_TableNextRow(ctx)
         reaper.ImGui_TableSetColumnIndex(ctx, 0)
         retval, seq1 = reaper.ImGui_InputText(ctx, "seq1", seq1, nil)
         reaper.ImGui_TableSetColumnIndex(ctx, 1)
         retval, octave1 = reaper.ImGui_InputText(ctx, "octave1", octave1, nil)
         
         reaper.ImGui_TableNextRow(ctx)
         reaper.ImGui_TableSetColumnIndex(ctx, 0)
         retval, seq2 = reaper.ImGui_InputText(ctx, "seq2", seq2, nil)
         reaper.ImGui_TableSetColumnIndex(ctx, 1)
         retval, octave2 = reaper.ImGui_InputText(ctx, "octave2", octave2, nil)
         
         reaper.ImGui_TableNextRow(ctx)
         reaper.ImGui_TableSetColumnIndex(ctx, 0)
         retval, seq3 = reaper.ImGui_InputText(ctx, "seq3", seq3, nil)
         reaper.ImGui_TableSetColumnIndex(ctx, 1)
         retval, octave3 = reaper.ImGui_InputText(ctx, "octave3", octave3, nil)
         
         reaper.ImGui_TableNextRow(ctx)
         reaper.ImGui_TableSetColumnIndex(ctx, 0)
         retval, seq4 = reaper.ImGui_InputText(ctx, "seq4", seq4, nil)
         reaper.ImGui_TableSetColumnIndex(ctx, 1)
         retval, octave4 = reaper.ImGui_InputText(ctx, "octave4", octave4, nil)
         
         reaper.ImGui_TableNextRow(ctx)
         reaper.ImGui_TableSetColumnIndex(ctx, 0)
         retval, seq5 = reaper.ImGui_InputText(ctx, "seq5", seq5, nil)
         reaper.ImGui_TableSetColumnIndex(ctx, 1)
         retval, octave5 = reaper.ImGui_InputText(ctx, "octave5", octave5, nil)
         
         reaper.ImGui_TableNextRow(ctx)
         reaper.ImGui_TableSetColumnIndex(ctx, 0)
         retval, seq6 = reaper.ImGui_InputText(ctx, "seq6", seq6, nil)
         reaper.ImGui_TableSetColumnIndex(ctx, 1)
         retval, octave6 = reaper.ImGui_InputText(ctx, "octave6", octave6, nil)
         
         reaper.ImGui_TableNextRow(ctx)
         reaper.ImGui_TableSetColumnIndex(ctx, 0)
         retval, seq7 = reaper.ImGui_InputText(ctx, "seq7", seq7, nil)
         reaper.ImGui_TableSetColumnIndex(ctx, 1)
         retval, octave7 = reaper.ImGui_InputText(ctx, "octave7", octave7, nil)
      reaper.ImGui_EndTable(ctx)
      end
--[[
      --
      -- pitch + octave offset from default 0 / base pitch + octave
      --
      reaper.ImGui_PushItemWidth(ctx, 75)
      retval, pitchBase = reaper.ImGui_InputInt(ctx, "pitch base", pitchBase)
      reaper.ImGui_PushItemWidth(ctx, 75) 
      --reaper.ImGui_SetCursorPos(ctx, (w / 2) - 100, 262)
      retval, octaveBase = reaper.ImGui_InputInt(ctx, "octave base", octaveBase, nil)
      ]]--
      --reaper.ImGui_SetCursorPos(ctx, (w / 2) - 100, 284)
      reaper.ImGui_PushItemWidth(ctx, 75) 
      retval, octaveSize = reaper.ImGui_InputInt(ctx, "octave size", octaveSize, nil)
      --[[
      --
      -- pitch preset menu
      --
      --reaper.ImGui_SetCursorPos(ctx, (w / 2) - 100, 306)
      --reaper.ImGui_SetCursorPos(ctx, (w / 2) - 100, 320)
      reaper.ImGui_PushItemWidth(ctx, 100)
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
]]--
      --
      -- process button
      --
      --reaper.ImGui_SameLine(ctx, nil, nil)
      if reaper.ImGui_Button(ctx, 'process', 100, nil) then 
        makeButton()
      end

      --
      -- transformed origin print
      -- popup button
      --
      reaper.ImGui_SameLine(ctx, nil, nil)
      if reaper.ImGui_Button(ctx, 'print', 42, nil) then 
         reaper.ImGui_OpenPopup(ctx, 'Transformed sequence')
      end
  
      if reaper.ImGui_BeginPopupModal(ctx, 'Transformed sequence', nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then 
         reaper.ImGui_Text(ctx, 'original sequences:')
         reaper.ImGui_Separator(ctx)
         reaper.ImGui_Text(ctx, 'origin : ' .. origin)
         reaper.ImGui_Text(ctx, 'seq0 : ' .. seq0)
         reaper.ImGui_Text(ctx, 'seq0 : ' .. seq1)
         reaper.ImGui_Text(ctx, 'seq0 : ' .. seq2)
         reaper.ImGui_Text(ctx, 'seq0 : ' .. seq3)
         reaper.ImGui_Text(ctx, 'seq0 : ' .. seq4)
         reaper.ImGui_Text(ctx, 'seq0 : ' .. seq5)
         reaper.ImGui_Text(ctx, 'seq0 : ' .. seq6)
         reaper.ImGui_Text(ctx, 'seq0 : ' .. seq7)
         reaper.ImGui_Separator(ctx)
         reaper.ImGui_Text(ctx, 'final transformed sequence:')
         reaper.ImGui_Separator(ctx)
         --reaper.ImGui_SetWindowFontScale(1.8) 
         reaper.ImGui_Text(ctx, dump(p.johnsonseq_origin_final))
         if reaper.ImGui_Button(ctx, 'Close') then
            reaper.ImGui_CloseCurrentPopup(ctx)  
         end
         reaper.ImGui_EndPopup(ctx)
      end


      --
      -- popup origin error 
      --
      if lengthChecker == true then
         reaper.ImGui_OpenPopup(ctx, 'Origin_Error')
         if reaper.ImGui_BeginPopupModal(ctx, 'Origin_Error', unused_open, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
            reaper.ImGui_Text(ctx, 'Cannot compute!')
            reaper.ImGui_Text(ctx, 'Your dataset is too small.')
            if reaper.ImGui_Button(ctx, 'Close') then
               reaper.ImGui_CloseCurrentPopup(ctx)  
               lengthChecker = false
            end
            reaper.ImGui_EndPopup(ctx)
         end
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
origin = "10010"
seq0 = "10011"
seq1 = "0110"
seq2 = "0"
seq3 = "0"
seq4 = "0"
seq5 = "0"
seq6 = "0"
seq7 = "0"
seq8 = "0"
octave0 = "0"
octave1 = "1"
octave2 = "2"
octave3 = "3"
octave4 = "4"
octave5 = "5"
octave6 = "6"
octave7 = "7"
--pitchBase = 0
--octaveBase = 3
octaveSize = 12
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
   pitch0 = "0"
   pitch1 = "2"
   pitch2 = "4"
   pitch3 = "5"
   pitch4 = "7"
   pitch5 = "9"
   pitch6 = "11"
   pitch7 = "12"
end

function presetMinor()
   pitch0 = "0"
   pitch1 = "2"
   pitch2 = "3"
   pitch3 = "5"
   pitch4 = "7"
   pitch5 = "8"
   pitch6 = "10"
   pitch7 = "12"
end

function presetLydian()
   pitch0 = "0"
   pitch1 = "2"
   pitch2 = "4"
   pitch3 = "6"
   pitch4 = "7"
   pitch5 = "9"
   pitch6 = "11"
   pitch7 = "13"
end