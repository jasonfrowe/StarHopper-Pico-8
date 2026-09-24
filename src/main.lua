-- main: pico-8 entry points and game flow
-- state: "play", "failed" (boss timed out: retry), "over"

ht=8 -- playfield top; the hud sits above it

function _init()
 stars_init()
 new_game()
end

function new_game()
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
 stars_update()
 if state=="play" then
  play_update()
 elseif btnp(4) or btnp(5) then
  if (state=="failed") start_level(lvl) else new_game()
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
   state="over"
   music_play("gameover")
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
 stars_draw()
 boss_draw()
 enemies_draw()
 objs_draw()
 shots_draw()
 player_draw()
 hud_draw()
 if (banner) cprint("level "..lvl,60,7)
 if (state=="failed") cprint("level failed",60,8)
 if (state=="over") cprint("game over",60,8)
end
