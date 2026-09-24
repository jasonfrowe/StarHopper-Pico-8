-- shots: player bullets (sprite 1)

function shots_init()
 shots={}
end

function shot_fire(x,y)
 if (#shots<8) add(shots,{x=x,y=y})
end

function shots_update()
 for s in all(shots) do
  s.y-=1.6 -- 4px/frame originally
  if (s.y<-8) del(shots,s)
 end
end

function shots_draw()
 for s in all(shots) do
  spr(1,s.x,s.y)
 end
end
