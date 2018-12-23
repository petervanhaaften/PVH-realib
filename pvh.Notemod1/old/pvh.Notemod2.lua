
--------------------------------------------------------------------------------
-- Ex Machina Setup Code -- variables etc
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- REQUIRES
--------------------------------------------------------------------------------
package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

--local b = require 'euclid'
--local g = require 'euclid2-exported_GUI'

--------------------------------------------------------------------------------
-- GLOBAL VARIABLES START
--------------------------------------------------------------------------------

m = {} -- all ex machina data
-- user changeable defaults are marked with "(option)"
m.debug = true

-- default octave & key
-- due to some quirk, oct 4 is really oct 3...
m.oct = 4; m.key = 1; m.root = 0 -- (options, except m.root)

-- midi editor, take, grid
m.activeEditor, m.activeTake = nil, nil
m.ppqn = 960; -- default ppqn, no idea how to check if this has been changed.. 
m.reaGrid = 0

-- euclidean generator
m.eucF = true	-- generate euclid (option)
m.eucAccentF = false	-- generate accents (option)
m.eucRndNotesF = false	-- randomise notes (option)
m.eucPulses = 3; m.eucSteps = 8; m.eucRot = 0 -- default values (options)

-- note buffers and current buffer index
m.notebuf = {}; m.notebuf.i = 0; m.notebuf.max = 0

m.dupes = {} -- for duplicate note detection while randomising
m.euclid = {} -- for pattern generation

m.notes = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', 'C'}
m.scales = {
	{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, name = "Chromatic"},
	{0, 2, 4, 5, 7, 9, 11, 12, name = "Ionian / Major"},
	{0, 2, 3, 5, 6, 9, 10, 12, name = "Dorian"},
	{0, 1, 3, 5, 7, 8, 10, 12, name = "Phrygian"},
	{0, 2, 4, 6, 7, 9, 11, 12, name = "Lyndian"},
	{0, 2, 4, 5, 7, 9, 10, 12, name = "Mixolydian"},
	{0, 2, 3, 5, 7, 8, 10, 12, name = "Aeolian / Minor"},
	{0, 1, 3, 5, 6, 8, 10, 12, name = "Locrian"},
	{0, 3, 5, 6, 7, 10, 12,name = "Blues"},
	{0, 2, 4, 7, 9, 12,name = "Pentatonic Major"},
	{0, 3, 5, 7, 10, 12,name = "Pentatonic Minor"},
	{name = "Permute"}
}
-- a list of scales available to the note randomiser, more can be added manually if required
-- each value is the interval step from the root note of the scale (0) including the octave (12)


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
			reaper.MIDI_InsertNote(m.activeTake, t2[i][1], t2[i][2], t2[i][3], t2[i][4], t2[i][6], t2[i][7], t2[i][8], false)
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
		end	--while (t1[i][j]
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
-- GenProbTable(preProbTable, slidersTable, probTable)
-- creates an event probability table using values from sliders
--------------------------------------------------------------------------------
function GenProbTable(preProbTable, sliderTable, probTable)
	local debug = false
	if debug or m.debug then ConMsg("GenProbTable()") end
	local i, j, k, l = 1, 1, 1, 1
	local floor = math.floor
	ClearTable(probTable)
	for i, v in ipairs(preProbTable) do
		if sliderTable[j].val1 > 0 then
			for l = 1, (sliderTable[j].val1) do
			probTable[k] = preProbTable[i]
			k = k + 1
			end -- for l
		end -- if sliderTable[j]
		j = j + 1
	end
end
--------------------------------------------------------------------------------
-- GetNotesFromTake() - fill a note buffer from the active take
--------------------------------------------------------------------------------
function GetNotesFromTake()
	local debug = false
	if debug or m.debug then ConMsg("GetNotesFromTake()") end
	local i, t
	if m.activeTake then
		local _retval, num_notes, num_cc, num_sysex = reaper.MIDI_CountEvts(m.activeTake)
		if num_notes > 0 then 
			t = GetNoteBuf(); if t == nil then t = NewNoteBuf() end
			ClearTable(t)
			for i = 1, num_notes do
				_retval, selected, muted, startppq, endppq, channel, pitch, velocity = reaper.MIDI_GetNote(m.activeTake, i-1)
				t[i] = {}
				t[i][1] = selected
				t[i][2] = muted
				t[i][3] = startppq
				t[i][4] = endppq
				t[i][5] = endppq-startppq
				t[i][6] = channel
				t[i][7] = pitch
				t[i][8] = velocity
			end -- for i				
		end -- num_notes
	else -- no active take
		if debug or m.debug then ConMsg("No Active Take") end
	end -- m.activeTake
end
--------------------------------------------------------------------------------
-- Note Randomiser
--------------------------------------------------------------------------------
-- Randomiser button
--randomBtn.onLClick = function()
function randomBtn()
	local debug = false
	if debug or m.debug then ConMsg("\nrandomBtn.onLClick()") end
	if m.activeTake then
	        m.seqShift = 0; m.seqShiftMin = 0; m.seqShiftMax = 0 -- reset shift
		--seqShiftVal.label = tostring(m.seqShift)
		GenProbTable(m.preNoteProbTable, t_noteSliders, m.noteProbTable)
		if #m.noteProbTable == 0 then return end
		GenOctaveTable(m.octProbTable, octProbSldr)
		GetNotesFromTake() 
		RandomiseNotesPoly(m.noteProbTable)
	end --m.activeTake
end 
-- Randomiser options toggle logic

--------------------------------------------------------------------------------
-- RandomiseNotesPoly(noteProbTable)
--------------------------------------------------------------------------------
function RandomiseNotesPoly(noteProbTable)
	local debug = false
	if debug or m.debug then ConMsg("RandomiseNotesPoly()") end
	m.dupes.i = 1
	local  i = 1
	local t1, t2 = GetNoteBuf(), NewNoteBuf()
	CopyTable(t1, t2)
	while t2[i] do
		if t2[i][1] == true or m.rndAllNotesF then -- if selected, or all notes flag is true
			if i == 1 and m.rndFirstNoteF then -- if selected, the first not is always root of scale
				t2[i][7] = m.root
			else
				t2[i][7] = GetUniqueNote(t1, i, noteProbTable, m.octProbTable)
			end
		end
		i = i + 1
	end -- while t1[i]
	PurgeNoteBuf()
	InsertNotes()
	if m.rndPermuteF and m.activeTake then 
		__, pHash = reaper.MIDI_GetHash(m.activeTake, false, 0)
		m.pHash = pHash
	end
end
--------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- InitMidiExMachina
--------------------------------------------------------------------------------
function InitMidiExMachina()
        reaper.ClearConsole();

	local debug = false  
	if debug or m.debug then ConMsg("InitMidiExMachina()") end
	--PurgeNoteBuf()
	--InsertNotes()
		
	-- grab the midi editor, and active take
	m.activeEditor = reaper.MIDIEditor_GetActive()
	if m.activeEditor then
		m.activeTake = reaper.MIDIEditor_GetTake(m.activeEditor)
		__ = NewNoteBuf()
		if not m.activeTake then ConMsg("InitMidiExMachina() - No Active Take") end
	else
		ConMsg("InitMidiMachina() - No Active MIDI Editor")
	end -- m.activeEditor

	
	--randomBtn()

	ConMsg(GetNotesFromTake(m.activeTake))
	
	--[[
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

	m.activeEditor = reaper.MIDIEditor_GetActive()
	if m.activeEditor then
		m.activeTake = reaper.MIDIEditor_GetTake(m.activeEditor)
		if m.activeTake then 
			-- check for grid changes
			local grid = m.reaGrid
			m.reaGrid, __, __ = reaper.MIDI_GetGrid(m.activeTake)
			if grid ~= m.reaGrid then 
				GetReaperGrid(seqGridRad)
			--	seqGridRad.onLClick() -- update the sequence grid sizes
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

	SetDefaultScaleOpts();
	SetDefaultRndOptions(); SetDefaultRndSliders()
	SetDefaultSeqOptions(); SetDefaultSeqShift()
	SetDefaultSeqGridSliders(); SetDefaultAccLegSliders()
	SetDefaultEucOptions(); SetDefaultEucSliders()]]--
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

--GUI.Init()
--GUI.func = MainLoop()
--GUI.freq = 0
--GUI.Main()
------
--GUI.Val("Steps","0")
--GUI.Val("Pulses","0")
--GUI.Val("Rotation","0")
----
--MainLoop()
