-- sound: effects in sfx 52-62 (made by tools/make_sfx.py), all on channel 3
-- so they briefly replace the music's drums rather than the melody.
-- as in sfx.c, a sound interrupts one of the same or lower tier; a lower
-- tier is dropped while a higher one plays.

s_pfire,s_efire,s_tally,s_pick,s_low,s_edie,s_phit,s_pdie,s_xtra,s_clear,s_win=52,53,54,55,56,57,58,59,60,61,62
sfx_tier=split"1,1,2,2,2,3,4,4,4,4,4"
sfx_len=split"0.07,0.09,0.14,0.14,0.25,0.17,0.08,0.65,0.8,0.65,1.55"
snd_p,snd_t=0,0

function snd(n)
 local p=sfx_tier[n-51]
 if p>=snd_p or time()>snd_t then
  sfx(n,3)
  snd_p,snd_t=p,time()+sfx_len[n-51]
 end
end
