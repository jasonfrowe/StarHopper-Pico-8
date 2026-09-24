-- boss: the end-of-level fight, 7 variants (port of gameplay_boss.c)
-- a boss is 24x16 (3x2 sprites) with its weak spot drawn in colour 15:
-- grey when armoured, yellow when it can be hurt, red while flashing.
-- x speeds are rp6502 x 0.4, y speeds x 0.55 (the boss moves along one axis at a time)

-- the tour between waves: 16 pivots sweeping the width and dipping to y=40
-- (the original's 8 stayed above y=21). each boss starts at a different
-- pivot and later bosses tour faster.
bpx=split"52,101,77,52,28,3,28,52,77,101,101,52,3,3,28,52"
bpy=split"8,8,22,36,22,8,30,14,30,8,24,40,24,8,16,8"

function approach(a,b,s)
 return a<b and min(a+s,b) or max(a-s,b)
end

function boss_start()
 bv=min(lvl,7)
 bx,by,bhp,bmode=52,-16,48,"enter"
 bp0,bspd,bdir,bdodge=bv*5%16+1,1+bv*.08,1,0
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
  if (by>=8) by,bmode,bpiv=8,"pivot",bp0
 elseif bmode=="dive" then
  -- boss 2: out of the top, back up from under the player
  by-=1.67
  if bph==0 and by<=-16 then
   bx,by,bph=tx,130,1
  elseif bph==1 and by<=8 then
   by,bmode,bpiv=8,"pivot",bp0
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
  -- boss 3: straight down, chase the player along the bottom until
  -- lined up (or 1.5s), then straight back up to ram them
  if bph==0 then
   by+=1.67
   if (by>=112) by,bph,bsx=112,1,0
  elseif bph==1 then
   bx=approach(bx,tx,1.2)
   bsx+=1
   if (abs(bx-tx)<1 or bsx>90) bph=2
  else
   by-=1.67
   if (by<=8) by,bmode,bpiv=8,"pivot",bp0
  end
 else
  local x,y=bpx[bpiv],bpy[bpiv]
  bx,by=approach(bx,x,1.2*bspd),approach(by,y,1.1*bspd)
  if (bx==x and by==y) bpiv=(bpiv-1+bdir)%16+1
  -- dodge: a shot lined up under the weak spot may make the boss turn
  -- back along its tour (50%), then not again for 1.5s so it can't buzz
  bdodge-=1
  if bdodge<=0 then
   for s in all(shots) do
    if abs(s.x+4-bx-bwx-bww/2)<8 and s.y>by and s.y<by+48 then
     bdodge=20
     if rnd(1)<.5 then
      bdir,bdodge=-bdir,90
      bpiv=(bpiv-1+bdir)%16+1
     end
     break
    end
   end
  end
 end

 -- attacks only while touring: 3-volley bursts from the twin guns,
 -- started when the player is lined up (every 100 frames, the original
 -- waited 180), plus an aimed shot every 90-bv*6 frames. boss 6 bursts
 -- faster and adds a centre gun.
 if bmode=="pivot" then
  local cyc,iv=100,8
  bshot=(bshot or 0)+1
  if bshot>=90-bv*6 then
   fire_aimed({x=bx+8,y=by+12},em)
   bshot=0
  end
  if bv==6 then
   cyc,iv=70,3
   b6-=1
   if b6<=0 then
    ebullet(bx+8,by+16,0,1.67)
    b6=12
   end
  end
  bcyc=(bcyc+1)%cyc
  if (bcyc==0) bvol=0
  if bcyc<54 then
   bset=2
   bfire-=1
   if bvol<3 and bfire<=0 and (bvol>0 or abs(px-bx-8)<=12) then
    ebullet(bx+2,by+16,0,1.67,9)
    ebullet(bx+14,by+16,0,1.67,10)
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

 -- weak spot: boss 4 is only vulnerable while its minions are alive.
 -- a hit leaves the boss flashing and shaking, and invulnerable, for 40 frames
 bvul=bv!=4 or live_enemies()>0
 if bflash>0 then
  bflash-=1
 elseif bvul and shot_hit(bx+bwx,by+13,bww,3) then
  bhp-=4
  bflash=40
  score_add(100*mult)
  snd(s_bhit)
 end
 -- ramming the boss costs a quarter of the ship's health
 if can_hurt() and overlap(bx+bwx,by,bww,16,px+1,py+1,6,6) then
  player_hurt(12)
 end

 if bhp<=0 or btime>=14400 then
  -- beaten, or out of time (4 minutes) and the level is failed
  bfail=bhp>0
  if (not bfail) snd(s_clear)
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
 local n,s=(bv-1)*3+bset,bflash%4
 if (bvul) pal(15,10)
 if (bflash>0 and s<2) pal(split"7,7,7,7,7,7,7,7,7,7,7,7,7,7,7")
 if (bflash==0) s=4
 spr(96+n\5*32+n%5*3,bx+split"-1,1,0,0,0"[s+1],by+split"0,0,-1,1,0"[s+1],3,2)
 pal()
 pal(15,5)
 -- boss health: 1px per hp
 if (bhp>0) rectfill(40,ht+1,39+bhp,ht+2,8)
end
