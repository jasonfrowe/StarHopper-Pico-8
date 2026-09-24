-- main: pico-8 entry points and game flow

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
 music_play("level_0"..min(n,7))
 banner=true
 state="play"
end

function _update60()
 stars_update()
 if state=="play" then
  play_update()
 elseif btnp(4) or btnp(5) then
  new_game()
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
 end

 if pdead and pdt>=42 then
  if lives>0 then
   player_respawn()
  else
   state="over"
   music_play("gameover")
  end
 end

 -- todo: boss fight and bonus screen come between levels
 if (lvl_done and not pdead and not prise) start_level(lvl+1)
end

function _draw()
 cls()
 stars_draw()
 enemies_draw()
 objs_draw()
 shots_draw()
 player_draw()
 hud_draw()
 if (banner) print("level "..lvl,46,60,7)
 if (state=="over") print("game over",46,60,8)
end
