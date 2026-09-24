-- player: ship movement and firing
-- sprites (8x8): 16 idle, 17 right, 18 left, 19-21 explode
-- speeds are the rp6502 values scaled by 0.4 (320px -> 128px)

player_fire_rate=20 -- frames between shots (PLAYER_FIRE_RATE)

function player_init()
 px,py=60,112
 pspd=0.5 -- 1.25px/frame originally; speed pickups add 0.1 up to 0.9
 pspr=16
 pfire=0
end

function player_update()
 local dx,dy=0,0
 if (btn(0)) dx-=1
 if (btn(1)) dx+=1
 if (btn(2)) dy-=1
 if (btn(3)) dy+=1
 px=mid(0,px+dx*pspd,120)
 py=mid(10,py+dy*pspd,120)
 pspr=dx>0 and 17 or dx<0 and 18 or 16

 if (pfire>0) pfire-=1
 if (btn(4) or btn(5)) and pfire==0 then
  shot_fire(px,py-4)
  pfire=player_fire_rate
 end
end

function player_draw()
 spr(pspr,px,py)
end
