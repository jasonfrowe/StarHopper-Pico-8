-- stars: two-layer scrolling starfield
-- (the rp6502 version scrolls BG/FG tile planes; pico-8 draws them)

star_cols={1,5,12,11,10,6,8,7}

function stars_init()
 stars={}
 for i=1,48 do
  local fast=i%3==0
  add(stars,{
   x=rnd(128),y=rnd(128),
   spd=fast and 1.5 or 0.5,
   len=fast and 3 or 0,
   c=star_cols[1+flr(rnd(#star_cols))]
  })
 end
end

function stars_update()
 for s in all(stars) do
  s.y+=s.spd
  if s.y>=128 then
   s.y-=128+s.len
   s.x=rnd(128)
  end
 end
end

function stars_draw()
 for s in all(stars) do
  line(s.x,s.y,s.x,s.y+s.len,s.c)
 end
end
