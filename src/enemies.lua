-- enemies: the 7 enemy types and the wave director (port of enemy.c)
-- sprite for type t: 22+t*6, +0..2 flying, +3..5 dying
-- speeds are the rp6502 px/frame x 0.45

es,em,ef,ed=.45,.9,1.35,1.8 -- slow, medium, fast, dive

-- extra enemy types per sub-wave for levels 2-4 (a) and 5+ (a and b).
-- the c tables were zero-filled past 7 entries, so sub-waves 7-12 add type 0.
ext_a=split"1,2,3,4,5,6,4,0,0,0,0,0,0"
ext_b=split"3,4,5,6,0,1,2,0,0,0,0,0,0"
-- type 1 lanes: x, target y
t1p=split"22,48,99,48,61,61,38,74,83,74"
-- type 2 rectangle path (right-hand variant mirrors x)
t2p=split"-8,-8,3,8,117,8,117,120,3,120,-8,-8"
-- type 3 attack posts, variant 0 then 1: x,y per lane
t3p=split"18,30,42,41,61,35,83,44,106,32,24,44,46,34,67,46,88,36,110,42"

function level_start(n)
 lvl,sub_wave,lvl_done=n,0,false
 enemies,groups={},{}
 wstate,wtimer,wid=0,120,0
 tpx,tpy,pvx,pvy=px+4,py+4,0,0
end

-- chebyshev-normalised velocity, as in the original
function aim(x,y,tx,ty,s)
 local dx,dy=tx-x,ty-y
 local m=max(abs(dx),abs(dy))
 if (m==0) return 0,s
 return dx*s/m,dy*s/m
end

-- step o towards (tx,ty); true on arrival
function move_to(o,tx,ty,s)
 if abs(tx-o.x)<=s and abs(ty-o.y)<=s then
  o.x,o.y=tx,ty
  return true
 end
 local vx,vy=aim(o.x,o.y,tx,ty,s)
 o.x+=vx
 o.y+=vy
end

-- aimed shot leading the player by 3-10 frames, y offset oy
function fire_aimed(e,s,oy)
 local lead=mid(3,max(abs(tpx-e.x),abs(tpy-e.y))/s/2,10)
 local vx,vy=aim(e.x,e.y,
  mid(0,tpx+pvx*lead,127),
  mid(ht,tpy+pvy*lead,127)+(oy or 0),s)
 return ebullet(e.x,e.y,vx,vy)
end

-- ring of n bullets
function barrage(x,y,n,s)
 for i=1,n do
  ebullet(x,y,cos(i/n)*s,sin(i/n)*s)
 end
end

function wave_prepare()
 local s=sub_wave
 wlist={}
 -- zig-zag (type 0) ships always come as one chain of 5+2*(level-1),
 -- however many the level's tables ask for (a change from the original)
 local function q(t,n)
  if t==0 then
   if (count(wlist,0)>0) return
   n=3+lvl*2
  end
  for i=1,n do add(wlist,t) end
 end
 q(s<=6 and s or 12-s,5)
 local a=ext_a[s+1]
 if lvl==2 then q(a,1)
 elseif lvl==3 then
  if s==5 then q(6,2) q(5,1) else q(a,3) end
 elseif lvl==4 then q(a,5)
 elseif lvl>4 then q(a,5) q(ext_b[s+1],5) end
 new_wave()
end

-- start a wave from wlist (also used for boss minion waves)
function new_wave()
 wspawned,wvar=0,flr(rnd(2))
 wid+=1
 local n5=count(wlist,5)
 if n5>0 then
  local cols=min(n5,5)
  grp={cols=cols,n=0,total=n5,down=0,
   x=(120-(cols-1)*11)/2,
   y=21+count_type(5)\5*30,
   vx=wvar==0 and es or -es}
  add(groups,grp)
 end
 -- zig-zag waves are centred on the player
 worig=mid(28,px,92)
 wshots=1+flr(rnd(2))
end

function count_type(t)
 local n=0
 for e in all(enemies) do
  if (e.t==t) n+=1
 end
 return n
end

function spawn_enemy(t,k)
 local lane,rank=k%5,k\5
 local e={t=t,w=wid,k=k,f=0,ph=0,tm=0,ft=0,
  x=10+rnd(100),y=-8}
 if t==0 then
  e.x,e.o=worig,worig
 elseif t==1 then
  e.x=t1p[lane*2+1]+rank*3-2
  e.ty=t1p[lane*2+2]+rank*7
  e.y,e.shots,e.ft=136,6,4+lane*2+rank
 elseif t==2 then
  e.wp,e.ft,e.v=1,20+k*8,wvar
  e.x,e.y=t2_wp(0,wvar)
 elseif t==3 then
  local gr,i=count_type(3)\5,wvar*10+lane*2
  e.tx=t3p[i+1]+rank*3+(gr%2*4)*(wvar==0 and 1 or -1)
  e.ty=t3p[i+2]+rank*7+gr*10
  e.tm,e.ft,e.sp=480,6+k*2,k*2
 elseif t==4 then
  e.tm=36+k*12
 elseif t==5 then
  local g=grp
  e.g,e.hx,e.hy=g,g.n%g.cols*11,g.n\g.cols*10
  e.tx,e.ty=g.x+e.hx,g.y+e.hy
  e.x,e.y,e.ft=e.tx,-8-g.n\g.cols*7,30+k*10
  g.n+=1
 end
 add(enemies,e)
end

function t2_wp(i,v)
 local x=t2p[i*2+1]
 return v==0 and x or 120-x,t2p[i*2+2]
end

function zig_x(y,o)
 local p=max(0,(y+8)*1.4)%88
 return mid(6,mid(28,o,92)+(p<22 and p or p<66 and 44-p or p-88),114)
end

-- an enemy that leaves play is moved to y=999 and culled as offscreen
function enemy_move(e)
 local t,ph=e.t,e.ph
 e.tm-=1
 e.ft-=1
 if t==0 then
  if ph==0 then
   e.y+=em
   e.x=zig_x(e.y,e.o)
   if wshots>0 and e.y>=ht+11 and e.y<101 and rnd(64)<1 and fire_aimed(e,em) then
    wshots-=1
   end
   -- dive when crossing the player's column, but only from a third of the
   -- way down (the original allowed it near the top; waves centred on the
   -- player would then all dive at once instead of zig-zagging)
   if (abs(e.x-px)<=3 and e.y>=48) e.ph=1
  else
   e.y+=ed
  end
 elseif t==1 then
  if ph==0 then
   e.y-=es
   if (e.y<=e.ty) e.y,e.ph,e.tm=e.ty,1,84
  elseif ph==1 then
   if e.shots>0 and e.ft<=0 then
    fire_aimed(e,em,split"0,-4,0,4,0,-2"[7-e.shots])
    e.shots-=1
    e.ft=10
   end
   if (e.tm<=0) e.ph=2
  else
   e.y-=es
  end
 elseif t==2 then
  if e.y>=ht and e.ft<=0 then
   fire_aimed(e,es)
   e.ft=42
  end
  local tx,ty=t2_wp(e.wp,e.v)
  if move_to(e,tx,ty,em) then
   e.wp+=1
   if (e.wp>5) e.y=999
  end
 elseif t==3 then
  if ph==0 then
   if (move_to(e,e.tx,e.ty,em)) e.ph,e.tm=1,480
  elseif ph==1 then
   if e.ft<=0 then
    e.ft=fire_aimed(e,es,(e.sp%7-3)*13) and 8 or 2
    e.sp+=1
   end
   if (e.tm<=0) e.ph=2
  else
   e.y+=es
  end
 elseif t==4 then
  if ph==0 then
   e.y+=es
   if e.tm<=0 then
    e.vx,e.vy=aim(e.x,e.y,px,py,ed*1.5)
    e.ph=1
   end
  else
   e.x+=e.vx
   e.y+=e.vy
  end
 elseif t==5 then
  local g=e.g
  if ph==0 then
   if (move_to(e,e.tx,e.ty,em)) e.ph=1
  elseif g.go then
   e.x,e.y=g.x+e.hx,g.y+e.hy
  end
  if (e.y>=128) e.y=999
  if g.go and e.y>=ht and e.ft<=0 then
   fire_aimed(e,em)
   e.ft=52+e.k*6
  end
 elseif t==6 then
  local vx,vy=aim(e.x,e.y,px+4,py+4,ef)
  e.x+=vx
  e.y+=vy
  if abs(e.x-px-4)<=16 and abs(e.y-py-4)<=22 or e.y>=py then
   barrage(e.x,e.y,16,em)
   barrage(e.x,e.y,8,ef)
   e.y=999
  end
 end
end

function enemy_die(e)
 e.dying,e.f,e.dt=true,3,0
 snd(s_edie)
end

function groups_update()
 for g in all(groups) do
  local alive,ready=false,true
  for e in all(enemies) do
   if e.g==g then
    alive=true
    if (e.ph==0) ready=false
   end
  end
  if not alive and g.n>=g.total then
   del(groups,g)
  elseif g.go or ready and alive then
   g.go=true
   g.x+=g.vx
   local w=8+(g.cols-1)*11
   if g.x<=3 or g.x+w>=125 then
    g.x=mid(3,g.x,125-w)
    g.vx=-g.vx
    g.down+=7
   end
   local s=min(es,g.down)
   g.y+=s
   g.down-=s
  end
 end
end

function enemies_update()
 -- smoothed player velocity for aim leading
 local cx,cy=px+4,py+4
 pvx=(pvx*3+cx-tpx)/4
 pvy=(pvy*3+cy-tpy)/4
 tpx,tpy=cx,cy

 groups_update()
 for e in all(enemies) do
  if e.dying then
   e.dt+=1
   if e.dt%10==0 then
    e.f+=1
    if (e.f>5) del(enemies,e)
   end
  else
   enemy_move(e)
   e.f=time()*7.5\1%3
   if e.y>=ht and shot_hit(e.x,e.y,8,8) then
    score_kill(e.t)
    enemy_die(e)
   elseif e.x<-26 or e.x>154 or e.y<-35 or e.y>163 then
    del(enemies,e)
   end
  end
 end
 waves_update()
end

-- wstate 0: waiting, 1: spawning, 2: waiting for the wave to clear
function waves_update()
 if wstate==0 then
  if (lvl_done) return
  if wtimer>0 then
   wtimer-=1
  else
   wave_prepare()
   wstate=1
  end
 elseif wstate==1 then
  if wtimer>0 then
   wtimer-=1
   return
  end
  -- a run of type 5 spawns together as one formation
  repeat
   local t=wlist[wspawned+1]
   if #enemies>=32 then
    wtimer=1
    return
   end
   spawn_enemy(t,wspawned)
   wspawned+=1
  until wspawned>=#wlist or t!=5 or wlist[wspawned+1]!=5
  local n=wlist[wspawned+1]
  if n then
   wtimer=n==0 and 10 or n==5 and 0 or 30
  else
   wstate,wtimer=2,240
  end
 else
  wtimer-=1
  local clear=true
  for e in all(enemies) do
   if (e.w==wid) clear=false
  end
  if clear or wtimer<=0 then
   sub_wave+=1
   wstate=0
   if sub_wave>=13 then
    lvl_done=true
   elseif sub_wave>6 and sub_wave<11 then
    asteroids(1+flr(rnd(3)))
   end
  end
 end
end

-- contact with the player: the enemy is destroyed (no score)
function enemy_touch(x,y,w,h)
 for e in all(enemies) do
  if not e.dying and overlap(e.x,e.y,8,8,x,y,w,h) then
   enemy_die(e)
   return true
  end
 end
end

function enemies_draw()
 for e in all(enemies) do
  spr(22+e.t*6+e.f,e.x,e.y)
 end
end
