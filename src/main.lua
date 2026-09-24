-- main: pico-8 entry points and game flow
-- state: "title", "play", "clear" (ship glides off after the boss), "bonus",
-- "failed" (boss timed out: retry), "over", "win"

ht=8 -- playfield top; the hud sits above it

function _init()
 cartdata("jasonrowe_starhopper")
 hiscore=dget(0)
 stars_init()
 title_start()
end

function new_game()
 reload(0x1000,0x1000,0x1000) -- boss sprites, after the title's logo
 pgx=nil
 score_init()
 player_new_run()
 start_level(1)
end

function start_level(n)
 shots_init()
 objs_init()
 level_start(n)
 kills,boss={},false
 music_play("level_0"..min(n,7))
 banner=true
 state="play"
end

function _update60()
 -- fresh: fire pressed this frame (held from before doesn't count)
 local b=btn(4) or btn(5)
 fresh,held=b and not held,b
 stars_update()
 if state=="play" then
  play_update()
 elseif state=="clear" then
  -- glide to the tally spot, hold a second, then tally
  if pgx then player_update() else bt+=1 end
  if (bt>60) bonus_start()
 elseif state=="bonus" then
  bonus_update()
 elseif state=="failed" then
  if (fresh) start_level(lvl)
 else
  screens_update()
 end
end

function play_update()
 player_update()
 shots_update()
 objs_update()
 enemies_update()
 if (#enemies>0) banner=false

 -- player hitbox is 6x6 inside the 8x8 sprite
 if not pdead then
  local x,y=px+1,py+1
  if (objs_touch(x,y,6,6)) player_hurt(4)
  if (can_hurt() and enemy_touch(x,y,6,6)) player_hurt(4)
  if (boss) boss_update()
 end

 if pdead and pdt>=42 then
  if lives>0 then
   player_respawn()
  else
   gameover_start()
  end
 end

 if (lvl_done and not boss and state=="play" and not pdead) boss_start()
end

function cprint(s,y,c)
 print(s,64-#s*2,y,c)
end

function _draw()
 cls()
 pal(15,5) -- weak spot colour: grey unless a boss recolours it
 pal(1,state=="title" and 140 or 1,1) -- brighter blue for the logo
 stars_draw()
 boss_draw()
 enemies_draw()
 objs_draw()
 shots_draw()
 player_draw()
 if (state!="title") hud_draw()
 screens_draw()
 if (banner and state=="play") cprint("level "..lvl,60,7)
 if (state=="bonus") bonus_draw()
 if (state=="clear") cprint("level complete",60,7)
 if (state=="failed") cprint("level failed",60,8)
end
