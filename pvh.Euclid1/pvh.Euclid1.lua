--[[

Euclid Rhythm Generator

Basically this is a cut up version of Ex Machina (by RobU23):
https://github.com/RobU23/ReaScripts/wiki/MIDI-Ex-Machina

It differs from that script by offering only the ability
to generate a rhythm at a fixed pitch, without any of the other
many features presented in Ex Machina. It also includes a new GUI
for writing rhythms in the MIDI editor.

Eventually it will be possible to load text files which define rhythms at specific
points in a composition, and have this generator produce those midi items. That's really
the whole point of this script.

I definitely need to clean up this script. There are still multiple unused elements
included in this slashed up script.

]]--


--------------------------------------------------------------------------------
-- Ex Machina Setup Code -- variables etc
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- REQUIRES
--------------------------------------------------------------------------------
package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

local b = require 'euclid'

--------------------------------------------------------------------------------
-- GLOBAL VARIABLES START
--------------------------------------------------------------------------------

m = {} -- all ex machina data
-- user changeable defaults are marked with "(option)"
m.debug = false

-- default octave & key
-- due to some quirk, oct 4 is really oct 3...
m.oct = 4; m.key = 1; m.root = 0 -- (options, except m.root)

-- midi editor, take, grid
m.activeEditor, m.activeTake = nil, nil
m.ppqn = 960; -- default ppqn, no idea how to check if this has been changed.. 
m.reaGrid = 0

-- euclidean generator
m.eucF = true  -- generate euclid (option)
m.eucAccentF = false  -- generate accents (option)
m.eucRndNotesF = false  -- randomise notes (option)
m.eucPulses = 3; m.eucSteps = 8; m.eucRot = 0 -- default values (options)

-- note buffers and current buffer index
m.notebuf = {}; m.notebuf.i = 0; m.notebuf.max = 0

m.dupes = {} -- for duplicate note detection while randomising
m.euclid = {} -- for pattern generation

m.notes = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', 'C'}

m.seqShift = 0; m.seqShiftMin = -16; m.seqShiftMax = 16 -- shift notes left-right from sequencer

--------------------------------------------------------------------------------
-- Ex Machina Functions Start
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Wrap(n, max) -return n wrapped between 'n' and 'max'
--------------------------------------------------------------------------------
local function Wrap (n, max)
  n = n % max
  if (n < 1) then n = n + max end
  return n
end
--------------------------------------------------------------------------------
-- ConMsg(str) - outputs 'str' to the Reaper console
--------------------------------------------------------------------------------
local function ConMsg(str)
  reaper.ShowConsoleMsg(str .."\n")
end
--------------------------------------------------------------------------------
-- GenNoteAttributes(accF, accProb, accVal, legF, legVal) -- accent, legato only
--------------------------------------------------------------------------------
function GenNoteAttributes(accF, accProbTable, accSlider, legF, legProbTable)
  local debug = false
  if debug or m.debug then ConMsg("GenNoteAttributes()") end
  if not accF and not legF then return end
  local t1, t2 = GetNoteBuf(), NewNoteBuf()
  local i = 1
  local noteStart, noteEnd, noteLen = 0, 0, 0
  CopyTable(t1, t2)
  if debug and m.debug then PrintNotes(t2) end
  while t2[i] do
    if t2[i][1] then
      if accF then -- handle accent flag (8 = velocity)
        t2[i][8] = accProbTable[math.random(1, #accProbTable)]
      end -- end accent
      if legF ~= 1 then -- no legato when called by euclid
        if legF then -- handle legato flag (3 = noteStart, 4 = noteEnd, 5 = noteLen)
          noteLen = t2[i][5]
          if noteLen >= 960 + m.legato and noteLen <= 960 - m.legato then noteLen = 960 -- 1/4
          elseif noteLen >= 480 + m.legato and noteLen <= 480 - m.legato then noteLen = 480 -- 1/8
          elseif noteLen >= 240 + m.legato and noteLen <= 240 - m.legato then noteLen = 240 -- 1/16
          end
          t2[i][4] = t2[i][3] + noteLen + legProbTable[math.random(1, #legProbTable)]
        end -- legato     
      end -- t2[i]
    end --selected
    i = i + 1    
  end -- while t1[i]
  if debug and m.debug then PrintNotes(t2) end
  PurgeNoteBuf()
  InsertNotes()
end
--------------------------------------------------------------------------------
-- SetNotes - arg notebuf t1; set notes in the active take
--------------------------------------------------------------------------------
function SetNotes()
  local debug = false
  if debug or m.debug then ConMsg("SetNotes()") end
  local i = 1
  if m.activeTake then
    local t1 = GetNoteBuf()
    while t1[i] do
      reaper.MIDI_SetNote(m.activeTake, i-1, t1[i][1], t1[i][2], t1[i][3], t1[i][4], t1[i][6], t1[i][7], t1[i][8], __)
      --1=selected, 2=muted, 3=startppq, 4=endppq, 5=len, 6=chan, 7=pitch, 8=vel, noSort)    
      i = i + 1
    end -- while t1[i]
    reaper.MIDI_Sort(m.activeTake)
    reaper.MIDIEditor_OnCommand(m.activeEditor, 40435) -- all notes off
  else
    if debug or m.debug then ConMsg("No Active Take") end
  end -- m.activeTake
end
--------------------------------------------------------------------------------
-- NewNoteBuf() - add a new note buffer to the table, returns handle
--------------------------------------------------------------------------------
local function NewNoteBuf()
  local debug = false
  if debug or m.debug then ConMsg("NewNoteBuf()") end
  m.notebuf.i = m.notebuf.i + 1
  m.notebuf.max = m.notebuf.max + 1
  m.notebuf[m.notebuf.i] = {}
  if debug or m.debug then
    str = "created buffer\n"
    str = str .. "buffer index = " .. tostring(m.notebuf.i) .. "\n"
    ConMsg(str)
  end
  return m.notebuf[m.notebuf.i]
end
--------------------------------------------------------------------------------
-- GetNoteBuf() - returns handle to the current note buffer
--------------------------------------------------------------------------------
local function GetNoteBuf()
  local debug = false
  if debug or m.debug then ConMsg("GetNoteBuf()") end
  if m.notebuf.i >= 1 then
    if debug or m.debug then
      str = "retrieved buffer\n"
      str = str .. "buffer index = " .. tostring(m.notebuf.i) .. "\n"
      ConMsg(str)
    end
    return m.notebuf[m.notebuf.i]
  end
end  
--------------------------------------------------------------------------------
-- InsertNotes(note_buffer) - insert notes in the active take
--------------------------------------------------------------------------------
function InsertNotes()
  local debug = false
  if debug or m.debug then ConMsg("\nInsertNotes()") end
  DeleteNotes()
  local i = 1
  if m.activeTake then
    local gridSize = m.reaGrid * m.ppqn
    local itemLength = GetItemLength()  
    local noteShift = m.seqShift * gridSize
    local t1 = GetNoteBuf()  
    local t2 = {} -- for note shifting
    local pitch = GUI.Val("Pitch")
    CopyTable(t1, t2)
    for k, v in pairs(t2) do -- do note shifting
      v[3] = v[3] + noteShift
      v[4] = v[4] + noteShift      
      if v[3] < 0 then
        v[3] = itemLength + v[3]
        v[4] = itemLength + v[4]  
          if v[4] > itemLength then v[4] = itemLength + m.legato end
      elseif v[3] >= itemLength then
        v[3] = v[3] - itemLength
        v[4] = v[4] - itemLength        
      end
    end
    while t2[i] do
      reaper.MIDI_InsertNote(m.activeTake, t2[i][1], t2[i][2], t2[i][3], t2[i][4], t2[i][6], pitch, t2[i][8], false)
      --1=selected, 2=muted, 3=startppq, 4=endppq, 5=len, 6=chan, 7=pitch, 8=vel, noSort)    
      i = i + 1
    end -- while t2[i]
    reaper.MIDI_Sort(m.activeTake)
    reaper.MIDIEditor_OnCommand(m.activeEditor, 40435) -- all notes off
  else
    if debug or m.debug then ConMsg("No Active Take") end
  end -- m.activeT
end
--------------------------------------------------------------------------------
-- DeleteNotes() - delete all notes from the active take
--------------------------------------------------------------------------------
function DeleteNotes()
  local debug = false
  if debug or m.debug then ConMsg("DeleteNotes()") end
  local i, num_notes = 0, 0
  if m.activeTake then
    __, num_notes, __, __ = reaper.MIDI_CountEvts(m.activeTake)
    for i = 0, num_notes do
      reaper.MIDI_DeleteNote(m.activeTake, 0)
    end --for
  else
    if debug or m.debug then ConMsg("No Active Take") end
  end --m.activeTake  
end

--------------------------------------------------------------------------------
-- ClearTable(t) - set all items in 2D table 't' to nil
--------------------------------------------------------------------------------
function ClearTable(t)
  local debug = false
  if debug or m.debug then ConMsg("ClearTable()") end
  for k, v in pairs(t) do
    t[k] = nil
  end
end
--------------------------------------------------------------------------------
-- CopyTable(t1, t2) - copies note data from t1 to t2
--------------------------------------------------------------------------------
function CopyTable(t1, t2)
  ClearTable(t2)
  local i = 1
  while t1[i] do
    local j = 1
    t2[i] = {}    
    while (t1[i][j] ~= nil)   do
      t2[i][j] = t1[i][j]
      j = j + 1
    end  --while (t1[i][j]
    i = i + 1
  end -- while t1[i]
end
--------------------------------------------------------------------------------
-- NewNoteBuf() - add a new note buffer to the table, returns handle
--------------------------------------------------------------------------------
local function NewNoteBuf()
  local debug = false
  if debug or m.debug then ConMsg("NewNoteBuf()") end
  m.notebuf.i = m.notebuf.i + 1
  m.notebuf.max = m.notebuf.max + 1
  m.notebuf[m.notebuf.i] = {}
  if debug or m.debug then
    str = "created buffer\n"
    str = str .. "buffer index = " .. tostring(m.notebuf.i) .. "\n"
    ConMsg(str)
  end
  return m.notebuf[m.notebuf.i]
end
--------------------------------------------------------------------------------
-- GetNoteBuf() - returns handle to the current note buffer
--------------------------------------------------------------------------------
local function GetNoteBuf()
  local debug = false
  if debug or m.debug then ConMsg("GetNoteBuf()") end
  if m.notebuf.i >= 1 then
    if debug or m.debug then
      str = "retrieved buffer\n"
      str = str .. "buffer index = " .. tostring(m.notebuf.i) .. "\n"
      ConMsg(str)
    end
    return m.notebuf[m.notebuf.i]
  end
end  
--------------------------------------------------------------------------------
-- UndoNoteBuf() - points to previous note buffer
--------------------------------------------------------------------------------
local function UndoNoteBuf()
  local debug = false
  if debug or m.debug then ConMsg("UndoNoteBuf()") end
  if m.notebuf.i > 1 then
    m.notebuf.i = m.notebuf.i -1
    if debug or m.debug then
      str = "removed buffer " .. tostring(m.notebuf.i + 1) .. "\n"
      str = str .. "buffer index = " .. tostring(m.notebuf.i) .. "\n"
      ConMsg(str)
    end
  else
    if debug or m.debug then
      str = "nothing to undo...\n"
      str = str .. "buffer index = " .. tostring(m.notebuf.i) .. "\n"
      ConMsg(str)
    end
  end
end
--------------------------------------------------------------------------------
-- PurgeNoteBuf() - purge all note buffers from current+1 to end
--------------------------------------------------------------------------------
local function PurgeNoteBuf()
  local debug = false
  if debug or m.debug then
    ConMsg("PurgeNoteBuf()")
    ConMsg("current idx = " .. tostring(m.notebuf.i))
    ConMsg("max idx     = " .. tostring(m.notebuf.max))
  end
  while m.notebuf.max > m.notebuf.i do
    m.notebuf[m.notebuf.max] = nil
    if debug or m.debug then ConMsg("purging buffer " .. tostring(m.notebuf.max))
    end
    m.notebuf.max = m.notebuf.max - 1
  end  
end
--------------------------------------------------------------------------------
-- GetItemLength(t) - get length of take 't', set various global vars
-- currently it only returns the item length (used in Sequencer and Euclid)
--------------------------------------------------------------------------------
function GetItemLength()
  local debug = false
  if debug or m.debug then ConMsg("GetItemLength()") end
  mItem = reaper.GetSelectedMediaItem(0, 0)
  mItemLen = reaper.GetMediaItemInfo_Value(mItem, "D_LENGTH")
  mBPM, mBPI = reaper.GetProjectTimeSignature2(0)
  msPerMin = 60000
  msPerQN = msPerMin / mBPM
  numQNPerItem = (mItemLen * 1000) / msPerQN
  numBarsPerItem = numQNPerItem / 4
  ItemPPQN = numQNPerItem * m.ppqn
  if debug or m.debug then
    ConMsg("ItemLen (ms)    = " .. mItemLen)
    ConMsg("mBPM            = " .. mBPM)
    ConMsg("MS Per QN       = " .. msPerQN)
    ConMsg("Num of QN       = " .. numQNPerItem)
    ConMsg("Num of Bar      = " .. numBarsPerItem)
    ConMsg("Item size ppqn  = " .. ItemPPQN .. "\n")
  end
  return ItemPPQN
end
--------------------------------------------------------------------------------
-- GetReaperGrid() - get the current grid size, set global var m.reaGrid
--------------------------------------------------------------------------------
function GetReaperGrid(gridRad)
  local debug = false
  if debug or m.debug then ConMsg("GetReaperGrid()") end
  if m.activeTake then
    m.reaGrid, __, __ = reaper.MIDI_GetGrid(m.activeTake) -- returns quarter notes
    if gridRad then -- if a grid object was passed, update it
      if m.reaGrid == 0.25 then gridRad.val1 = 1 -- 1/16
      elseif m.reaGrid == 0.5 then gridRad.val1 = 2 -- 1/8
      elseif m.reaGrid == 1 then gridRad.val1 = 3 -- 1/4
      end -- m.reaGrid
    end
  else 
    if debug or m.debug then ConMsg("No Active Take\n") end
  end -- m.activeTake
end
--------------------------------------------------------------------------------
-- SetSeqGridSizes()  
--------------------------------------------------------------------------------
function SetSeqGridSizes(sliderTable)
  local debug = false
  if debug or m.debug then ConMsg("SetSeqGridSizes()") end
  for k, v in pairs(sliderTable) do
    if sliderTable[k].label == "1/16" then m.preSeqProbTable[k] = 0.25
    elseif sliderTable[k].label == "1/8" then m.preSeqProbTable[k] = 0.5
    elseif sliderTable[k].label == "1/4" then m.preSeqProbTable[k] = 1.0
    elseif sliderTable[k].label == "Rest" then m.preSeqProbTable[k] = -1.0
    end
  end
end
--------------------------------------------------------------------------------
-- GenBjorklund(pulses, steps, rotation, accProbTable, accSlider)
--------------------------------------------------------------------------------

function GenBjorklund(pulses, steps, rotation, accProbTable, accSlider)
        local debug = false
  if debug or m.debug then ConMsg("GenBjorklund()") end
  local floor = math.floor
  local t, t2 = NewNoteBuf(), GetNoteBuf()
  CopyTable(t2, t)
  GetReaperGrid() -- populates m.reaGrid
  --t = GetNoteBuf(); if t == nil then t = NewNoteBuf() end -- pre-undo
  ClearTable(t)
  local itemPos = 0
  local gridSize = m.reaGrid * m.ppqn
  local itemLength = GetItemLength()
  local noteStart, noteEnd, noteLen, noteVel = 0, 0, 0, 0
  local newNote = 0
  local noteCount = 0; restCount = 0
  local pulse = floor(GUI.Val("Pulses"))
  local step = floor(GUI.Val("Steps"))
  local pattern = b.generate(pulse, step)
  local rot = floor(GUI.Val("Rotation"))
  local idx = (-rot) + 1
  local idx = Wrap(idx, step)
  while itemPos < itemLength do
    if pattern[idx] then
      noteStart = itemPos
      noteLen = gridSize
      noteEnd = noteStart + noteLen
      itemPos = itemPos + noteLen
      if m.eucAccentF then  -- handle accent flag
        noteVel = accProbTable[math.random(1, #accProbTable)]
      else
        noteVel = 50
      end -- m.seqAccentF      
      --noteVel = accProbTable[math.random(1, #accProbTable)]
      noteCount = noteCount + 1
      t[noteCount] = {}
      t[noteCount][1] = true                -- selected
      t[noteCount][2] = false               -- muted
      t[noteCount][3] = noteStart           -- startppqn
      t[noteCount][4] = noteEnd + 0         -- endppqn
      t[noteCount][5] = noteLen             -- note length
      t[noteCount][6] = 0                   -- channel
      t[noteCount][7] = 30             -- note number
      t[noteCount][8] = 100             -- velocity
    else
      itemPos = itemPos + gridSize
      restCount = restCount + 1
    end
    idx = idx + 1
    idx = Wrap(idx, step)
  end
  PurgeNoteBuf()
  InsertNotes()
  
  --add take "name" (label) of number of notes
  local newname = pulse .. "pul " .. step .. "stp " .. rot .. "rot " --new label string
  local item  = reaper.GetSelectedMediaItem(0, 0)
  local take = reaper.GetActiveTake(item)
  reaper.ULT_SetMediaItemNote(item, name)
  retval, stringNeedBig = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", newname, 1)
end
--------------------------------------------------------------------------------
-- Euclidiser
--------------------------------------------------------------------------------
-- Euclidiser button
function Euclidiser()
  local debug = false
  if debug or m.debug then ConMsg("\neuclidBtn.onLClick()") end
  if m.activeTake then
    if m.eucF then
      if debug or m.debug then ConMsg("m.eucF = " .. tostring(m.eucF)) end
      --GenAccentTable(m.accProbTable, seqAccRSldr, seqAccProbSldr)
      --GetNotesFromTake()
      --pvh edit start
      --orig: GenBjorklund(euclidPulsesSldr, euclidStepsSldr, euclidRotationSldr, m.accProbTable, seqAccRSldr)
      --function GenBjorklund(pulses, steps, rotation, accProbTable, accSlider)
      GenBjorklund(pulses, steps, rotation, accProbTable, accSlider)
      --pvh edit end
      --if m.eucRndNotesF then 
      --  randomBtn.onLClick() -- call RandomiseNotes
      --end
    else -- not m.eucF
      if debug or m.debug then ConMsg("m.eucF = " .. tostring(m.eucF)) end
      GenAccentTable(m.accProbTable, seqAccRSldr, seqAccProbSldr)
      GetNotesFromTake()
      GenNoteAttributes(m.eucAccentF, m.accProbTable, seqAccRSldr, false, m.legProbTable)
      if m.eucRndNotesF then 
        if debug or m.debug then ConMsg("m.eucRndNotesF = " .. tostring(m.eucRndNotesF)) end
        randomBtn.onLClick() -- call RandomiseNotes
      end    
    end -- m.eucF
    -- set project ext state    
    --pExtState.eucSliders = {}
    --for k, v in pairs(t_euclidSliders) do
    --  pExtState.eucSliders[k] = v.val1
    --end
    --pExtSaveStateF = true
  end -- m.activeTake
end
-- Euclidiser options
function EucOptions()
        local debug = false
  if debug or m.debug then ConMsg("\neucOptionsCb.onLClick()") end
  m.eucF =          eucOptionsCb.val1[1] == 1 and true or false -- Generate
  m.eucAccentF =    eucOptionsCb.val1[2] == 1 and true or false -- Accent
  m.eucRndNotesF = eucOptionsCb.val1[3] == 1 and true or false -- Randomise notes
  pExtState.eucOptionsCb = {m.eucF, m.eucAccentF, m.eucRndNotesF}
  pExtSaveStateF = true
  if debug or m.debug then PrintTable(eucOptionsCb.val1) end
end




-- Set default euclid options
function SetDefaultEucOptions()
  local debug = false
  if debug or m.debug then ConMsg("SetDefaultEucOptions()") end
  -- if euclidean options were saved to project state, load them
  if pExtState.eucOptionsCb then 
    m.eucF =           pExtState.eucOptionsCb[1] ==  true and true or false
    m.eucAccentF =     pExtState.eucOptionsCb[2] ==  true and true or false
    m.eucRndNotesF =   pExtState.eucOptionsCb[3] ==  true and true or false
  end
  -- set euclidean options using defaults, or loaded project state
  eucOptionsCb.val1[1] = (true and m.eucF) and 1 or 0 -- generate
  eucOptionsCb.val1[2] = (true and m.eucAccentF) and 1 or 0 -- accents
  eucOptionsCb.val1[3] = (true and m.eucRndNotesF) and 1 or 0 -- randomise notes
end

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- InitMidiExMachina
--------------------------------------------------------------------------------
function InitMidiExMachina()

  local debug = false  
  if debug or m.debug then ConMsg("InitMidiExMachina()") end 
  
  -- grab the midi editor, and active take
  m.activeEditor = reaper.MIDIEditor_GetActive()
  if m.activeEditor then
    m.activeTake = reaper.MIDIEditor_GetTake(m.activeEditor)
    __ = NewNoteBuf()
    if not m.activeTake then ConMsg("InitMidiExMachina() - No Active Take") end
  else
    ConMsg("InitMidiMachina() - No Active MIDI Editor")
  end -- m.activeEditor
  
  GetItemLength()
  --GetNotesFromTake() -- grab the original note data (if any...)
  if debug or m.debug then ConMsg("End InitMidiExMachina()\n") end
end


--------------------------------------------------------------------------------
-- Mainloop
--------------------------------------------------------------------------------
function MainLoop()

local pulse = GUI.Val("Pulses")


--[[   -- check for midi editor and take
  m.activeEditor = reaper.MIDIEditor_GetActive()
  if m.activeEditor then
    m.activeTake = reaper.MIDIEditor_GetTake(m.activeEditor)
    if m.activeTake then 
      -- check for grid changes
      local grid = m.reaGrid
      m.reaGrid, __, __ = reaper.MIDI_GetGrid(m.activeTake)
      if grid ~= m.reaGrid then 
        GetReaperGrid(seqGridRad)
      --  seqGridRad.onLClick() -- update the sequence grid sizes
      end -- grid
    else -- handle m.activeTake error
      ShowMessage(msgText, 1) 
      m.activeTake = nil
    end -- m.activeTake
  else -- handle m.activeEditor error
    -- pop up error message - switch layer on textbox element
    ShowMessage(msgText, 1)
    m.activeEditor = nil
    m.activeTake = nil
  end -- m.activeEditor

  Euclidiser()]]--
return
end





--------------------------------------------------------------------------------
-- RUN
--------------------------------------------------------------------------------

InitMidiExMachina()
--MainLoop()
--------------------------------------------------------------------------------
 




----
----
----
----
-- Script generated by Lokasenna's GUI Builder


local lib_path = reaper.GetExtState("Lokasenna_GUI", "lib_path_v2")
if not lib_path or lib_path == "" then
    reaper.MB("Couldn't load the Lokasenna_GUI library. Please run 'Set Lokasenna_GUI v3 library path.lua' in the Lokasenna_GUI folder.", "Whoops!", 0)
    return
end
loadfile(lib_path .. "Core.lua")()




GUI.req("Classes/Class - Button.lua")()
GUI.req("Classes/Class - Textbox.lua")()
-- If any of the requested libraries weren't found, abort the script.
if missing_lib then return 0 end



GUI.name = "pvh.euclid"
GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, 150, 197
GUI.anchor, GUI.corner = "mouse", "C"

function test()
 end

GUI.New("make", "Button", {
    z = 11,
    x = 64.0,
    y = 144.0,
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
    undo_limit = 20
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
    undo_limit = 20
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
    undo_limit = 20
})


GUI.New("Pitch", "Textbox", {
    z = 11,
    x = 64,
    y = 112,
    w = 40,
    h = 20,
    caption = "Pitch",
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
GUI.func = MainLoop()
GUI.freq = 0
GUI.Main()
-----
GUI.Val("Steps","0")
GUI.Val("Pulses","0")
GUI.Val("Rotation","0")
GUI.Val("Pitch","60")
----
--MainLoop()
