-- objs: enemy bullets, asteroids, pickups and explosions (port of projectile.c)
-- kinds: 1 bullet (spr 2), 2 asteroid (6-8), 3 pickup (3 e, 4 s, 5 p), 4 explosion (11-13)

-- pickups dropped by asteroids, in order (0 = nothing): p e - s e e p e - e
pick_seq=split"5,3,0,4,3,3,5,3,0,3"

function objs_init()
 objs,pick_i={},0
end

function obj(k,x,y,vx,vy,f)
 if #objs<32 then
  local o={k=k,x=x,y=y,vx=vx,vy=vy,f=f,t=0}
  add(objs,o)
  return o
 end
end

function ebullet(x,y,vx,vy,f)
 snd(s_efire)
 return obj(1,x,y,vx,vy,f or 2)
end

function boom(o)
 o.k,o.f,o.t,o.vx,o.vy=4,11,0,0,0
end

function asteroids(n)
 for i=0,n-1 do
  obj(2,3+rnd(114),-i*7,0,.5,6)
 end
end

function overlap(ax,ay,aw,ah,bx,by,bw,bh)
 return ax<bx+bw and bx<ax+aw and ay<by+bh and by<ay+ah
end

-- hitbox of a bullet (2x4 in its 8x8 cell) or an 8x8 object
function obj_box(o)
 if (o.k==1) return o.x+3,o.y+2,2,4
 return o.x,o.y,8,8
end

function objs_update()
 for o in all(objs) do
  local k=o.k
  o.x+=o.vx
  o.y+=o.vy
  o.t+=1
  if k==2 then
   if (o.t%6==0) o.f=6+(o.f-5)%3
   -- shot asteroids explode and may drop a pickup
   if shot_hit(o.x,o.y,8,8) then
    local f=pick_seq[pick_i+1]
    pick_i=(pick_i+1)%10
    if (f>0) obj(3,o.x,o.y,rnd{-.8,.8},.14,f)
    boom(o)
   end
  elseif k==3 then
   if (o.x<=0 or o.x>=120) o.vx=-o.vx
  elseif k==4 then
   if o.t%4==0 then
    o.f+=1
    if (o.f>13) del(objs,o)
   end
  end
  if o.x<-8 or o.x>128 or o.y>128 or o.y<(k==1 and ht or -24) then
   del(objs,o)
  end
 end
end

-- the player's hitbox against bullets, asteroids and pickups
function objs_touch(x,y,w,h)
 local hurt
 for o in all(objs) do
  local ox,oy,ow,oh=obj_box(o)
  if o.k<4 and overlap(ox,oy,ow,oh,x,y,w,h) then
   if o.k==3 then
    player_pickup(o.f)
    del(objs,o)
   elseif can_hurt() and not hurt then
    hurt=true
    if (o.k==2) boom(o) else del(objs,o)
   end
  end
 end
 return hurt
end

function objs_draw()
 for o in all(objs) do
  spr(o.f,o.x,o.y)
 end
end
