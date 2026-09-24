-- screens: title, game over and the victory parade
-- (ports of the title scene, enemy.c's game over letters and gameplay_game_over.c)
-- both end screens return to the title on a press, or after 108.8s

rainbow=split"8,9,10,11,12,13,14"

function title_start()
 state,tt,pgx="title",0
 -- the logo is kept in the unused upper map: copy it over the boss sprites
 -- (sheet rows 64+) while the title shows; new_game restores them
 memcpy(0x1000,0x2000,2560)
 player_spawn(pstart)
 enemies,groups,boss={},{}
 objs_init()
 shots_init()
 music_play("title")
end

function save_hiscore()
 if score>hiscore then
  hiscore=score
  dset(0,score)
 end
end

function gameover_start()
 state,tt="over",0
 save_hiscore()
 music_play("gameover")
 -- g a m e o v e r fly in from all sides
 letters={}
 for i=0,7 do
  local l={tx=32+i*8,ty=70}
  local k=i%4
  l.x=k==0 and -8-i*2 or k==1 and 136+i*2 or k==2 and 13+i*11 or 112-i*9
  l.y=k==0 and 17+i*10 or k==1 and 11+i*9 or k==2 and -8-i*3 or 136+i*3
  add(letters,l)
 end
end

function win_start()
 state,tt,wr,wy,wph="win",0,0,-16,0
 snd(s_win)
 save_hiscore()
 music_play("victory")
end

function screens_update()
 tt+=1
 if state=="title" then
  if (fresh) new_game()
  return
 end
 if state=="over" then
  ldone=true
  for l in all(letters) do
   if (tt<8 or not move_to(l,l.tx,l.ty,.45)) ldone=false
  end
 else
  -- fireworks, and each boss in turn parades down with 4 of its
  -- level's enemies circling it (5 laps)
  if (tt%18==0) obj(4,10+rnd(100),12+rnd(94),0,0,11)
  objs_update()
  if tt>60 then
   if wph==0 then
    wy+=1.1
    if (wy>=79) wy,wph,wo=79,1,0
   else
    wo+=1/48
    if (wo>=5) wph=2
    if (wph==2) wy+=1.67
    if (wy>128) wr,wy,wph=(wr+1)%7,-16,0
   end
  end
 end
 if fresh and tt>120 and (state=="win" or ldone) or tt>6528 then
  title_start()
 end
end

function screens_draw()
 local c=rainbow[tt\6%7+1]
 if state=="title" then
  sspr(0,64,100,39,14,16)
  cprint("hi "..score_str(hiscore),4,7)
  if (tt%40<28) cprint("press button",104,c)
 elseif state=="over" then
  for i,l in pairs(letters) do
   spr(63+i,l.x,l.y)
  end
  if (ldone and tt%40<28) cprint("press button",104,7)
 elseif state=="win" then
  local n=wr*3
  spr(96+n\5*32+n%5*3,52,wy,3,2)
  if wph>0 then
   for k=0,3 do
    spr(22+min(wr,6)*6,60+10*cos(wo+k/4),wy+4+9*sin(wo+k/4))
   end
  end
  cprint("you win",40,c)
 end
end
