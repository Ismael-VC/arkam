require: lib/core.f


( ===== Image area and There pointer ===== )

: kilo 1000 * ;
256 kilo        as: image_max
image_max allot as: there


( memory layout )

0x04 as: addr_start
0x08 as: addr_here
0x10 as: addr_begin


( relative pointer )

val: mhere

: m>t there + ; # &meta -- &there
: t>m there - ; # &there -- &meta

: m@  m>t @ ;
: m!  m>t ! ;
: bm@ m>t b@ ;
: bm! m>t b! ;

: mhere! ( adr -- )
  dup 0             <  IF .. "invalid mhere" panic THEN
  dup image_max - 0 >= IF .. "invalid mhere" panic THEN
  dup mhere!
  addr_here m!
;


: mhere:align! mhere align mhere! ;

: m,  mhere m!  mhere cell + mhere! ;
: bm, mhere bm! mhere inc    mhere! ;

: m0pad 0 bm, mhere:align! ;

: entrypoint! ( madr -- ) addr_start m! ;

: image_size mhere m>t there - ;

( initialize )
addr_begin mhere!


( ----- save ----- )

MODULE

  val: id

---EXPOSE---

  : save ( fname -- )
    "wb" file:open! id!
    there image_size id file:write!
    id file:close!
  ;

  : save: ( fname: -- )
    in:read [ "out name required" panic ] unless
    save
  ;
END


( ----- string ----- )

: m:sput ( s -- )
  dup s:len inc >r mhere m>t s:copy r> mhere + mhere! mhere:align!
;


( ===== Meta Dictionary ===== )

# Structure
#  | name ...
#  | ( 0alined )
#  | next
#  | &name
#  | flags
#  | handler
#  | xt
#  |-----
#  | code ...

MODULE

---EXPOSE---

  ( latest )
  mhere as: adr_mlatest
  0 m,

  : mlatest  adr_mlatest m@ ;
  : mlatest! adr_mlatest m! ;

  : mcreate ( name -- )
    # create meta-dict entry
    mhere:align!
    mhere swap m:sput mhere:align! # -- &name
    mhere mlatest m, mlatest! # -- &name
    ( &name   ) m,
    ( flags   ) 0 m,
    ( handler ) 0 m,
    ( xt      ) mhere cell + m,
  ;

END


( ===== debug ===== )

: mdump ( madr len -- ) [ m>t ] dip dump ;
: minfo
  "there 0x" pr there ?hex drop cr
  "here  0x" pr mhere ?hex drop cr
  "start 0x" pr addr_start m@ ?hex drop cr
;

( ===== prim ===== )

: prim ( n -- code ) 1 << 1 or ;
: prim, ( n -- ) prim m, ;


"main" mcreate
mhere entrypoint!
2 prim, 42 m, 1 prim,

minfo
0 64 mdump
save: out/tmp.ark
bye
