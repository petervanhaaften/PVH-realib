function Msg(str)
  reaper.ShowConsoleMsg(tostring(str) .. "\n")
end
-------------------------------
-- GLOBAL VARIABLES
-------------------------------
reaper.ClearConsole();

-- Get HWND
hwnd = reaper.MIDIEditor_GetActive()

-- Get current take being edited in MIDI Editor
take = reaper.MIDIEditor_GetTake(hwnd)

-- Debug info
Msg(hwnd)
Msg(take)

-- Loop through each selected note
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take) -- count all notes(events)
i = 0
check = 0
notes_selected=0

-- hold all data
p = {}
p.newnotes = {}

--test
array = {5, 2, 6, 3, 6}
-------------------------------
-- FUNCTIONS
-------------------------------
function makenoteBuffer()
   --builds note buffer of equal numnber elements to selected notes
   for i=0, notes-1 do --loops through all notes in take
      local retval, sel, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
      if sel == true then -- find which notes are selected
	 p.newnotes.i = (60 + math.random(10))
	 Msg("pitch table")
	 Msg(p.newnotes.i)
	 --Msg(60 + math.random(10))--p.newnotes(notes-1) = 60 + rnd(50)
      end
      i=i+1
      --Msg("loop = ".." ".."i") -- print to console to check how many loop goes (even if item not selected)
   end
end


function getselectedNotes()
   for i=0, notes-1 do --loops through all notes in take
      local retval, sel, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
      if sel == true then -- find which notes are selected
	 check = check + 1 -- if notes selected add it to check count
	 --Msg(retval)
	 --Msg(startppq)
	 --Msg(endppq)
      end
      i=i+1
      Msg("loop = ".." ".."i") -- print to console to check how many loop goes (even if item not selected)
   end
end

function compareBuffers()
   for i=0, notes-1 do --loops through all notes in take
      Msg("pitchnew")
      Msg(array.i)
      
--      for i, value in next, array do
--	 Msg(value)
--      end
      --Msg(newpitch)
      if sel == true then -- find which notes are selected
	 reaper.MIDI_InsertNote(take, sel, muted, startppq, endppq, chan, 60, vel, false)
	 --1=selected, 2=muted, 3=startppq, 4=endppq, 5=len, 6=chan, 7=pitch, 8=vel, noSort)	
      end
      i=i+1
      Msg("loop = ".." ".."i") -- print to console to check how many loop goes (even if item not selected)
   end
end

-------------------------------
-- MAIN
-------------------------------

getselectedNotes()
makenoteBuffer()
compareBuffers()

--[[
reads notes
puts each current note into origin buffer
have another buffer available, new note buffer
pull out each note from origin buffer, change pitch according to same index in new notes buffer
insert new note at same position as origin note
]]--
