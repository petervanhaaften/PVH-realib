
function Msg(param)
  --reaper.ShowConsoleMsg(tostring(param).."/n")
end

function Main()
track = reaper.GetSelectedTrack(0, 0)
okay, note = reaper.GetUserInputs("Note Number", 1, "Note Number", "1")

if okay == false then goto ending
end
-- read time selection
starttime, endtime = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
qnotetime = 60 / reaper.Master_GetTempo()

if starttime == endtime then -- no time selection exists

   -- check if a mediaItem is selected, and if so take its start & end times and delete it
   if reaper.CountSelectedMediaItems() == 0 then
      starttime = reaper.GetCursorPosition()
      endtime = starttime + qnotetime
   else
      selectedItem = reaper.GetSelectedMediaItem(0, 0)
      starttime = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
      endtime = starttime + reaper.GetMediaItemInfo_Value(selectedItem, "D_LENGTH")
      reaper.DeleteTrackMediaItem(track, selectedItem)
   end      
end

length = (endtime - starttime)
--actually making the notes
midiItem = reaper.CreateNewMIDIItemInProj(track, starttime, starttime + qnotetime)
midiTake = reaper.GetActiveTake(midiItem)
reaper.MIDI_InsertNote(midiTake, false, false, 0, 480, 1, note, 127)
reaper.MIDI_InsertNote(midiTake, false, false, 0, 480, 2, note+20, 127)
--set some info about the take
reaper.SetMediaItemInfo_Value(midiItem, "B_LOOPSRC", 1)
reaper.SetMediaItemLength(midiItem, length, false)
reaper.GetSetMediaItemTakeInfo_String(midiTake, 'P_NAME', note, true)

::ending::
end
Main()
-- reaper.ShowConsoleMsg("complete!")

-- boolean reaper.MIDI_InsertNote(MediaItem_Take take, boolean selected, boolean muted, number startppqpos, 
-- number endppqpos, integer chan, integer pitch, integer vel, optional boolean noSortIn)
