-- bonus: end-of-level tally (port of level_bonus.c)
-- a row per enemy type (kills x points x level), then the boss bonus; the total
-- pays into the score, then kills heal the ship. hold fire to hurry it along.
-- totals are 32-bit integers stored >>16, like the score.

function bonus_start()
 state,bph,brow,bt,btot,bic="bonus",0,0,0,0,-8
 local n=0
 for t=0,6 do n+=kills[t] or 0 end
 -- 1hp per 3 kills (max 24), +6 for the boss
 bheal=min(24,n\3)+6
 shots_init()
 objs_init()
 music_play("bonus")
end

function row_pts(r)
 return enemy_points(r)*lvl
end

-- phases: 0 icon flies in, 1 count kills, 2 hold, 3 pay out, 4 heal, 5 done
function bonus_step()
 bt+=1
 local k=kills[brow] or 0
 if bph==0 then
  bic=min(bic+1.6,8)
  if (bic==8) bph,bt,bcnt=1,0,0
 elseif bph==1 then
  if bt%6==0 and bcnt<k then
   bcnt+=1
   snd(s_tally)
  end
  if bcnt>=k then
   btot+=(k>>16)*row_pts(brow)
   bph,bt=2,0
  end
 elseif bph==2 then
  if bt>=36 then
   brow+=1
   bt=0
   if brow<7 then
    bph,bic=0,-8
   elseif brow==7 then
    btot+=10000>>16
   else
    bph=3
   end
  end
 elseif bph==3 then
  if btot<=0 then
   bph=4
  elseif bt%3==0 then
   -- pay out in steps of 100, 40, 12, then the remainder
   local p=btot<<16
   for s in all{100,40,12} do
    if btot>=s>>16 then p=s break end
   end
   score_add(p)
   btot-=p>>16
   snd(s_tally)
  end
 elseif bph==4 then
  if bheal<=0 or php>=48 then
   bph=5
  elseif bt%6==0 then
   php+=1
   bheal-=1
   snd(s_tally)
  end
 end
end

function bonus_update()
 for i=1,held and 8 or 1 do
  if (bph<5) bonus_step()
 end
 if bph==5 and fresh then
  if lvl>=7 then
   win_start()
  else
   start_level(lvl+1)
   pgx,pgy=60,pstart
  end
 end
end

function bonus_draw()
 cprint("level "..lvl.." bonus",12,7)
 for r=0,min(brow,6) do
  local y=22+r*9
  spr(22+r*6,r<brow and 8 or bic,y)
  if r<brow or bph>0 then
   local k=r<brow and (kills[r] or 0) or bcnt
   print(k.." x "..row_pts(r),20,y+2,6)
   local s=tostr((k>>16)*row_pts(r),2)
   print(s,120-#s*4,y+2,7)
  end
 end
 if (brow>=7) print("boss",20,87,10) print("10000",100,87,10)
 cprint("bonus "..tostr(btot,2),97,9)
 if (bph==5 and time()%1<.6) cprint("press button",120,7)
end
