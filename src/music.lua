-- music: each tune lives in its own cart in music/ (made by tools/vgm2p8.py)
-- and is copied into sfx 0-51 + all 64 music patterns before playing.
-- sfx 52-63 are left alone for game sound effects.

music_cur=nil
-- tools/export.py sets this to "" (exports store bundled carts without folders)
mdir="music/"

function music_play(name)
 if (name==music_cur) return
 music(-1)
 reload(0x3100,0x3100,0x0ed0,mdir..name..".p8")
 music(0)
 music_cur=name
end
