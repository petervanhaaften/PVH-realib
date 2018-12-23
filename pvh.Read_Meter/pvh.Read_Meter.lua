function Msg(param)
  reaper.ShowConsoleMsg(tostring(param).."/n")
end

function Main()
  cursor_pos = reaper.GetCursorPosition()

  file = assert(io.open("/Users/pvh/src/Reaper_scripts/lua/newinst_read1/test_times.txt", r))
  array = {}
  i = 0
  
  -- main loop reads through txt file.
  for line in file:lines() do
    val0 = 0
    val1 = 0
    val2 = 0
    wnum = 0
    -- inner loop seperates each element on each line 
    for w in line:gmatch("%S+") do     
      -- there are 3 elements, copy them into val0, val1, or val2 respectfully
      if wnum < 3 then
        if wnum == 0 then
          val0 = w
        end
        if wnum == 1 then
          val1 = w
        end
        if wnum == 2 then
          val2 = w
        end
        wnum = wnum + 1        
      end

    end

    --creates a timesigmarker for every line read
    reaper.AddTempoTimeSigMarker(0, val2, 100, val0, val1,true)

    array[i]=line
    i=i+1
  end
  
end

Main()
reaper.ShowConsoleMsg("complete!")
