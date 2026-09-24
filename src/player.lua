-- player: movement, firing, health, death and respawn (port of player_controller.c)
-- sprites: 16 idle, 17 right, 18 left, 19-21 explode

pspd0,pstart=.5625,77 -- base speed (1.25px/frame x 0.45), resting y

function player_new_run()
 pspd,prate,lives=pspd0,20,2
 player_spawn(77)
end

function player_spawn(y)
 px,py,php,pfire,phit,pflash,pinv,pspr=60,y,48,0,0,0,0,16
 pdead=false
end

function can_hurt()
 return not pdead and not prise and pinv==0 and phit==0
end

function player_hurt(n)
 php=max(0,php-n)
 phit,pflash=108,96
 score_hit()
 if php==0 then
  -- death costs two speed levels and two power levels
  pdead,pdt=true,0
  pspd=max(pspd0,pspd-.225)
  prate=min(20,prate+2)
 end
end

function player_pickup(f)
 if f==3 then php=min(48,php+8)
 elseif f==4 then pspd=min(pspd0+.45,pspd+.1125)
 else prate=max(16,prate-1) end
end

-- rise from the bottom with 3s of blinking invincibility
function player_respawn()
 lives-=1
 player_spawn(120)
 prise,pinv=true,180
end

function player_update()
 if (phit>0) phit-=1
 if (pflash>0) pflash-=1
 if pdead then
  pdt+=1
  return
 end
 if (pinv>0) pinv-=1
 if prise then
  py-=1
  if (py<=pstart) py,prise=pstart,false
  return
 end

 local dx,dy=0,0
 if (btn(0)) dx-=1
 if (btn(1)) dx+=1
 if (btn(2)) dy-=1
 if (btn(3)) dy+=1
 px=mid(0,px+dx*pspd,120)
 py=mid(ht,py+dy*pspd,120)
 pspr=16+(dx>0 and 1 or dx<0 and 2 or 0)

 if (pfire>0) pfire-=1
 if btn(4) or btn(5) then
  if pfire==0 then
   shot_fire(px,py-4)
   pfire=prate
  end
 end
end

function player_draw()
 if pdead then
  -- explode frames 19-21, 10 frames each
  if (pdt<42) spr(19+min(2,pdt\10),px,py)
  return
 end
 if (pinv>0 and pinv\6%2==1) return
 -- flash white and shake when hit, flash red on low health
 local sx,sy=0,0
 if pflash>0 then
  if (pflash%4<2) pal(split"7,7,7,7,7,7,7,7,7,7,7,7,7,7,7")
  sx,sy=split"-1,1,0,0"[pflash%4+1],split"0,0,-1,1"[pflash%4+1]
 elseif php<=12 and time()%.5<.25 then
  pal(split"8,8,8,8,8,8,8,8,8,8,8,8,8,8,8")
 end
 spr(pspr,px+sx,py+sy)
 pal()
end
