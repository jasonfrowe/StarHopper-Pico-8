-- score: points, multiplier, extra lives (port of score.c)
-- pico-8 numbers stop at 32767, so the score is kept as a 32-bit integer
-- shifted right 16 bits and printed with tostr(score,2)

function score_init()
 score,mult,streak,kills=0,1,0,{}
 next_life=0x1.86a0 -- 100000>>16
end

function enemy_points(t)
 return t==6 and 100 or min(40,10+t*5)
end

function score_add(p)
 score=min(score+(p>>16),0xf.423f) -- cap at 999999
 if score>=next_life then
  next_life+=0x1.86a0
  if lives<3 then
   lives+=1
   snd(s_xtra)
  end
 end
end

-- two kills without being hit raise the multiplier, up to x5
function score_kill(t)
 kills[t]=(kills[t] or 0)+1
 score_add(enemy_points(t)*mult)
 streak+=1
 if (streak%2==0 and mult<5) mult+=1
end

function score_hit()
 mult,streak=1,0
end

function score_str(v)
 return sub("00000"..tostr(v or score,2),-6)
end

-- hud strip above the playfield
function hud_draw()
 rectfill(0,0,127,ht-1,0)
 line(0,ht-1,127,ht-1,2)
 print(score_str(),1,1,10)
 -- health bar: 48hp in 24px, red when low
 rect(51,1,76,5,5)
 -- speed (blue) and power (red) pickups collected, 4 pips each
 for i=1,4 do
  if (i<=(pspd-pspd0)/.1125+.5) rectfill(25+i*3,1,26+i*3,2,12)
  if (i<=20-prate) rectfill(25+i*3,4,26+i*3,5,8)
 end
 if (php>0) rectfill(52,2,51+php/2,4,php<=12 and 8 or 11)
 print("x"..mult,84,1,mult>1 and 9 or 5)
 spr(16,108,-1)
 print(lives,118,1,7)
end
