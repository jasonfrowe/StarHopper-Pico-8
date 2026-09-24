-- main: pico-8 entry points

function _init()
 stars_init()
 player_init()
 shots_init()
end

function _update60()
 stars_update()
 player_update()
 shots_update()
end

function _draw()
 cls()
 stars_draw()
 shots_draw()
 player_draw()
end
