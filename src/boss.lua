-- boss: the end-of-level fight, 7 variants (port of gameplay_boss.c)
-- a boss is 24x16 (3x2 sprites) with its weak spot drawn in colour 15:
-- grey when armoured, yellow when it can be hurt, red while flashing.
-- x speeds are rp6502 x 0.4, y speeds x 0.55 (the boss moves along one axis at a time)

-- the tour of 8 pivots between waves
bpx=split"3,52,101,101,52,3,3,52"
bpy=split"8,8,15,21,21,15,21,8"

function approach(a,b,s)
 return a<b and min(a+s,b) or max(a-s,b)
end

function boss_start()
 bv=min(lvl,7)
 bx,by,bhp,bmode,bpiv=52,-16,48,"enter",1
 btime,bwt,bwc,bcyc,bfire,bvol,bflash,bset,banim,b6=0,180,0,0,0,0,0,0,0,0
 bwave,bfail=false,false
 -- level 2's boss has a wider weak spot
 bwx,bww=bv==2 and 5 or 10,bv==2 and 14 or 5
 enemies,groups={},{}
 objs_init()
 music_play(bv==7 and "bossfinal" or "boss")
 boss=true
end

-- enemies still alive (not dying)
function live_enemies()
 local n=0
 for e in all(enemies) do
  if (not e.dying) n+=1
 end
 return n
end

function boss_update()
 -- defeated: explosions over the boss while the ship glides home
 if bmode=="dead" then
  px,py=approach(px,60,.5),approach(py,pstart,.5)
  btm-=1
  if btm%4==0 then
   for i=1,3 do
    obj(4,bx-2+rnd(24),max(ht,by-2+rnd(16)),0,0,11)
   end
  end
  if (btm<=0) bmode="leave"
  return
 end
 if bmode=="leave" then
  by-=1.1
  if by<=-16 then
   boss=false
   if (bfail) state="failed" else state,bt,pgx,pgy="clear",0,60,106
  end
  return
 end

 btime+=1
 -- boss x that centres it on the player
 local tx=mid(3,px-8,101)
 if bmode=="enter" then
  by+=1.1
  if (by>=8) by,bmode,bpiv=8,"pivot",1
 elseif bmode=="dive" then
  -- boss 2: out of the top, back up from under the player
  by-=1.67
  if bph==0 and by<=-16 then
   bx,by,bph=tx,130,1
  elseif bph==1 and by<=8 then
   by,bmode,bpiv=8,"pivot",1
  end
 elseif bmode=="drop" then
  -- boss 5: line up with the player, then fall through the screen twice
  if bph==0 then
   bx=approach(bx,tx,1.2)
   if (abs(bx-tx)<=7) bph=1
  else
   by+=3.3
   if bph==1 and by>=144 then
    bx,by,bph=tx,-18,2
   elseif bph==2 and by>=130 then
    by,bmode=-16,"enter"
   end
  end
 elseif bmode=="slide" then
  -- boss 3: sink to the bottom, slide under the player, rise
  if bph==0 then
   by+=1.67
   if (by>=112) by,bph,bsx=112,1,tx
  elseif bph==1 then
   bx=approach(bx,bsx,1.2)
   if (bx==bsx) bph=2
  else
   by-=1.67
   if (by<=8) by,bmode,bpiv=8,"pivot",1
  end
 else
  local x,y=bpx[bpiv],bpy[bpiv]
  bx,by=approach(bx,x,1.2),approach(by,y,1.1)
  if (bx==x and by==y) bpiv=bpiv%8+1
 end

 -- attacks only while touring: 3-volley bursts from the twin guns,
 -- started when the player is lined up. boss 6 is faster and adds a centre gun.
 if bmode=="pivot" then
  local cyc,iv=180,8
  if bv==6 then
   cyc,iv=120,3
   b6-=1
   if b6<=0 then
    obj(1,bx+8,by+16,0,1.67,2)
    b6=12
   end
  end
  bcyc=(bcyc+1)%cyc
  if (bcyc==0) bvol=0
  if bcyc<54 then
   bset=2
   bfire-=1
   if bvol<3 and bfire<=0 and (bvol>0 or abs(px-bx-8)<=7) then
    obj(1,bx+2,by+16,0,1.67,9)
    obj(1,bx+14,by+16,0,1.67,10)
    bvol+=1
    bfire=iv
   end
  else
   bfire=0
   banim+=1
   if (banim%24==0) bset=bset==0 and 1 or 0
  end
 else
  bcyc,bfire,b6,bset=0,0,0,0
 end

 -- weak spot: boss 4 is only vulnerable while its minions are alive
 bvul=bv!=4 or live_enemies()>0
 if bvul and shot_hit(bx+bwx,by+13,bww,3) then
  bhp-=4
  bflash=12
  score_add(100*mult)
 end
 if (bflash>0) bflash-=1
 if can_hurt() and overlap(bx+bwx,by,bww,16,px+1,py+1,6,6) then
  player_hurt(4)
 end

 if bhp<=0 or btime>=14400 then
  -- beaten, or out of time (4 minutes) and the level is failed
  bfail=bhp>0
  bmode,btm,bset,enemies=bfail and "leave" or "dead",180,0,{}
  objs_init()
  return
 end

 -- minion waves of type level-1; boss 7 sends chasers without pause
 if bwave then
  bws-=1
  if bws<=0 then
   spawn_enemy(wlist[1],wspawned)
   wspawned+=1
   bws=bv==7 and 24 or 12
   if (wspawned>=5) bwave,bwt=false,bv==7 and 0 or 420
  end
 elseif bmode!="enter" then
  bwt-=1
  if bwt<=0 then
   bwc+=1
   if (bwc==3 or bwc==6) asteroids(2)
   wlist,bwave,bws={},true,0
   for i=1,5 do add(wlist,min(lvl-1,6)) end
   new_wave()
   bph=0
   bmode=bv==2 and "dive" or bv==3 and "slide" or bv==5 and "drop" or bmode
  end
 end
end

function boss_draw()
 if (not boss) return
 local n=(bv-1)*3+bset
 if (bvul) pal(15,bflash%6>2 and 8 or 10)
 spr(96+n\5*32+n%5*3,bx,by,3,2)
 pal(15,5)
 -- boss health: 1px per hp
 if (bhp>0) rectfill(40,ht+1,39+bhp,ht+2,8)
end
