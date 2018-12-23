function Msg(param)
  reaper.ShowConsoleMsg(tostring(param).."/n")
end

function Main()
  --reaper.ShowConsoleMsg("this is a test")
  cursor_pos = reaper.GetCursorPosition()
  --reaper.ShowConsoleMsg(cursor_pos)
  --boolean reaper.AddTempoTimeSigMarker(ReaProject proj, number timepos, number bpm, integer timesig_num, integer timesig_denom, boolean lineartempochange)
--test = io.open("/Users/pvh/src/Reaper_scripts/lua/newinst_read1/test_times.tzt", "r")

  f = io.input("/Users/pvh/src/Reaper_scripts/lua/newinst_read1/test_times.txt") 
  --reaper.ShowConsoleMsg(test)
  reaper.AddTempoTimeSigMarker(0, cursor_pos, 300, 3, 3,true)
  
  
  
  --local BUFSIZE = 2^13     -- 8K
  --    local f =  io.input("/Users/pvh/src/Reaper_scripts/lua/newinst_read1/test_times.txt")
  --local cc, lc, wc = 0, 0, 0   -- char, line, and word counts
  --   while true do
  --     local lines, rest = f:read(BUFSIZE, "*line")
  --     if not lines then break end
  --     if rest then lines = lines .. rest .. '\n' end
  --     unpack(lines, 
  --     reaper.ShowConsoleMsg(lines)
  --   end
  
  --for line in test:lines() do
  --    local dollars, tickets = unpack(line:split(" "))
  --    print(dollars)
  --end
  local BUFSIZE = 2^13 
  local example = f
  while true do
       local lines, rest = f:read(BUFSIZE, "*line")
       if not lines then break end
       if rest then lines = lines .. rest .. '\n' end
       
       local line_vals = {}
       for w in (lines .. ";"):gmatch("([^;]*);") do 
           table.insert(line_vals, w) 
       end
       
       for n, w in ipairs(line_vals) do
          --reaper.ShowConsoleMsg(n .. ": " .. w)
          if n == 1 then
          reaper.ShowConsoleMsg(w) 
       end
       end
       --for i in string.gmatch(lines, "%S+") do
       --   reaper.AddTempoTimeSigMarker(0, cursor_pos, 300, 3, 3,true)
       --end
  end
  
  --while true do
    --local s = "one;two;;four"
    --local words = {}
    --for w in (s .. ";"):gmatch("([^;]*);") do 
    --    table.insert(words, w) 
    --end
    
    --for n, w in ipairs(words) do
    --    --reaper.ShowConsoleMsg(n .. ": " .. w)
    --    if n == 1 then
    --    reaper.ShowConsoleMsg(w) 
    --    end
   --end
 -- end
  --for i in string.gmatch(example, "%S+") do
  --  reaper.ShowConsoleMsg(i)
  --  reaper.ShowConsoleMsg("//")
  --end
end

Main()
