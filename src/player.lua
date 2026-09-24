-- player: ship movement and firing
-- sprite frames (16x16): 32 idle, 34 right, 36 left, 38-42 explode

player_fire_rate=20 -- frames between shots (PLAYER_FIRE_RATE)

function player_init()
 px,py=56,104
 pspd=1
 pspr=32
 pfire=0
end

function player_update()
 local dx,dy=0,0
 if (btn(0)) dx-=1
 if (btn(1)) dx+=1
 if (btn(2)) dy-=1
 if (btn(3)) dy+=1
 px=mid(0,px+dx*pspd,112)
 py=mid(8,py+dy*pspd,112)
 pspr=dx>0 and 34 or dx<0 and 36 or 32

 if (pfire>0) pfire-=1
 if (btn(4) or btn(5)) and pfire==0 then
  shot_fire(px+4,py-2)
  shot_fire(px+10,py-2)
  pfire=player_fire_rate
 end
end

function player_draw()
 spr(pspr,px,py,2,2)
end
