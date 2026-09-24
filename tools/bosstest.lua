-- boss test for tools/snap.py: jump straight to level bl's boss (default 1) with an
-- invincible autopilot that stays under the boss and fires; logs each boss mode change.
--   python3 tools/snap.py --frames 6000 --each "bl=3
--   $(cat tools/bosstest.lua)"
if i==1 then
 new_game()
 start_level(bl or 1)
 lvl_done=true
 can_hurt=function() return false end
 btn=function(b)
  if (b>3) return true
  local tx=boss and bx+8 or px
  return (b==0 and tx<px-1) or (b==1 and tx>px+1) or (b==2 and py>100)
 end
 lm=""
end
if boss and bmode!=lm then
 printh(i.." boss "..bv.." "..bmode.." hp "..bhp.." enemies "..#enemies.." score "..score_str())
 lm=bmode
end
if not boss and lm!="" then printh(i.." boss over: state "..state.." lvl "..lvl) lm="" end
