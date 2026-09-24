-- shots: player bullets (sprite 1, hitbox 2x4 at +3,+2)

function shots_init()
 shots={}
end

function shot_fire(x,y)
 if (#shots<8) add(shots,{x=x,y=y})
end

-- consume the first shot touching the box; true on a hit
function shot_hit(x,y,w,h)
 for s in all(shots) do
  if overlap(s.x+3,s.y+2,2,4,x,y,w,h) then
   del(shots,s)
   return true
  end
 end
end

function shots_update()
 for s in all(shots) do
  s.y-=1.8 -- 4px/frame originally
  if (s.y<ht-8) del(shots,s)
 end
end

function shots_draw()
 for s in all(shots) do
  spr(1,s.x,s.y)
 end
end
