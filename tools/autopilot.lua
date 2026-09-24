-- autopilot for tools/snap.py: python3 tools/snap.py --frames 20000 --each @tools/autopilot.lua
-- invincible ship that holds fire and tracks the lowest enemy; logs each sub-wave
if i==1 then
 can_hurt=function() return false end
 btn=function(b)
  if (b>3) return true
  local t
  for e in all(enemies) do
   if not e.dying and e.y>ht and (not t or e.y>t.y) then t=e end
  end
  if (not t) return false
  return (b==0 and t.x<px-1) or (b==1 and t.x>px+1)
 end
 lastl,lasts=0,-1
end
if lvl!=lastl or sub_wave!=lasts then
 printh(i.." lvl "..lvl.." wave "..sub_wave.." enemies "..#enemies.." objs "..#objs.." score "..score_str().." x"..mult.." lives "..lives)
 lastl,lasts=lvl,sub_wave
end
