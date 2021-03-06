function Msg(param)
  reaper.ShowConsoleMsg(tostring(param).."/n")
end

function Main()
  --textfile layout:
  --//tempo, beats, beats per bar, time sig marking position (in seconds)
  --//intend to add "glide to next tempo" time value ? 
  --//(ie, last 3 seconds, glide to next tempo)

  retval, filenameName = reaper.GetUserFileNameForRead("", "Open", ".txt") 
  file = assert(io.open(filenameName, r))
  array = {}
  i = 0
  
  -- main loop reads through txt file.
  for line in file:lines() do
    val0 = 0
    val1 = 0
    val2 = 0
    val3 = 0
    wnum = 0
    -- inner loop seperates each element on each line 
    for w in line:gmatch("%S+") do     
      -- there are 3 elements, copy them into val0, val1, val2, or val3 respectfully
      if wnum < 4 then
        if wnum == 0 then
          val0 = w
        end
        if wnum == 1 then
          val1 = w
        end
        if wnum == 2 then
          val2 = w
        end
	if wnum == 3 then
	  val3 = w
	end
        wnum = wnum + 1        
      end

    end

    --creates a timesigmarker for every line read
    reaper.AddTempoTimeSigMarker(0, val3, val0, val1, val2,false)

    array[i]=line
    i=i+1

  end

end

Main()
--reaper.ShowConsoleMsg("complete!")
