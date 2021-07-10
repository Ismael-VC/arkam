require: lib/core.f


( for debug )
val: verbose  no verbose!


# Naming and Abbrev
# x -- cross, works on target image
# m -- meta, works on metacompiler (this code)


( ===== Image area and There pointer ===== )

: kilo 1000 * ;
256 kilo        as: image_max
image_max allot as: there


( memory layout )

0x04 as: adr_start
0x08 as: adr_here
0x0C as: adr_xlatest
0x10 as: adr_begin


( relative pointer )

val: xhere

: x>t there + ; # &x -- &there
: t>x there - ; # &there -- &x

: x@  x>t @ ;
: x!  x>t ! ;
: bx@ x>t b@ ;
: bx! x>t b! ;

: xhere! ( xadr -- )
  dup 0             <  IF .. "invalid xhere" panic THEN
  dup image_max - 0 >= IF .. "invalid xhere" panic THEN
  dup xhere!
  adr_here x!
;


: xhere:align! xhere align xhere! ;

: x,  xhere x!  xhere cell + xhere! ;
: bx, xhere bx! xhere inc    xhere! ;

: x0pad 0 bx, xhere:align! ;

: entrypoint! ( xadr -- ) adr_start x! ;

: image_size xhere x>t there - ;

( initialize )
adr_begin xhere!


( ----- save ----- )

PRIVATE

  val: id

PUBLIC

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

: x:sput ( s -- )
  dup s:len inc >r xhere x>t s:copy r> xhere + xhere! xhere:align!
;



( ===== debug ===== )

PRIVATE

  16 as: bpl ( bytes per line )
  : space " " epr ;
  : cr "" eprn ;
  : ?addr ( a -- ) t>x dup 8 >> ?ff ?ff space ;
  : line ( addr len q -- ) swap [ 2dup [ b@ ] dip call &inc dip ] times 2drop ;
  : rest ( len q -- ) swap bpl swap - swap times ;
  : ascii? ( c -- ? ) dup 0x20 < IF drop no RET THEN 0x7E <= ;
  : pchar ( c -- ) dup ascii? IF [ putc ] >stderr ELSE drop "." epr THEN ;
  : ?bytes ( addr len -- ) swap over [ ?ff space ] line [ space space space ] rest ;
  : ?ascii ( addr len -- ) [ pchar ] line ;
  : ?line ( addr len -- ) over ?addr 2dup ?bytes ?ascii cr ;
  : loop ( addr len -- ) dup bpl > IF over bpl ?line [ bpl + ] [ bpl - ] bi* AGAIN THEN ?line ;

PUBLIC

  : xdump ( xadr len -- )
    [ x>t ] dip loop
  ;

END

: xinfo
  "there 0x" pr there ?hex drop cr
  "here  0x" pr xhere ?hex drop cr
  "start 0x" pr adr_start x@ ?hex drop cr
;



( ===== Cross&Meta Dictionary ===== )

# Cross Dictionary
#  | name ...
#  | ( 0alined )
#  | next | hidden? | immed? ( least 2 bit )
#  | &name
#  | xt
#  |-----
#  | code ...

PRIVATE

  "M-" as: mprefix

  : unknown_mode ? " unknown mode" panic ;

  : mhandle_normal ( xxt state -- )
    # called in compiling core.f on target image
    # xxt is xt address on target image
    forth:compile_mode [ x,                     ] ;CASE
    forth:run_mode     [ "called in meta" panic ] ;CASE
    unknown_mode
  ;

  ( ----- primitives ----- )

  : mhandle_prim ( xt state -- )
    # xt-> | prim code
    #      | run
    forth:compile_mode [ @ x,        ] ;CASE
    forth:run_mode     [ cell + @ >r ] ;CASE
    unknown_mode
  ;

  "M-           " as: prim_name ( 11 prim name space )
  prim_name 2 +   as: prim_buf
  10 as: prim_max

  : prim>code 1 << 1 or ;
  : xLIT, 2 prim>code x, ;
  : xLIT,, xLIT, x, ;
  : xRET, 3 prim>code x, ;
  : xJMP,  16 prim>code x, ;
  : xZJMP, 17 prim>code x, ;

  : mcreate_prim ( q num name -- )
    prim_buf s:copy ( LIT -> M-LIT )
    prim_name forth:create
    ( handler ) &mhandle_prim forth:latest forth:handler!
    ( code    ) prim>code ,
    ( q:run   ) ,
  ;

  : meta:num_handler ( n mode -- )
    forth:compile_mode [ xLIT,,   ] ;CASE
    forth:run_mode     [ ( -- n ) ] ;CASE
  ;
  
  : meta:amp_handler ( name mode -- )
    swap dup forth:find [ drop epr " ?" panic ] unless nip ( mode header -- )
    forth:xt swap
    forth:compile_mode [ xLIT,,    ] ;CASE
    forth:run_mode     [ ( -- xt ) ] ;CASE
    ? " unknown mode" panic
  ;

  34 as: dquote
  : meta:str_handler ( -- )
    forth:mode forth:compile_mode = IF
      xJMP, xhere 0 x, xhere swap # -- &str &back
    ELSE
      xhere # -- addr
    THEN

    [ in:take
      0      [ "Unclosed string" panic ] ;CASE
      dquote [ 0 bx, STOP              ] ;CASE
      bx, GO
    ] while
    xhere:align!

    forth:mode forth:compile_mode = IF
      xhere swap x! # backpatch
      xLIT,, # str
    THEN
  ;

  : meta:reveal
    [ ( header -- )
      dup forth:name mprefix s:start? [
        dup forth:name 2 + swap forth:name!
      ] ;when
      drop
    ] forth:each_word
  ;

  : meta:handle_nonmeta ( xt state -- )
    # Guard from compiling non-meta words
    forth:compile_mode [ "Attempt to compile non-meta word" panic ] ;CASE
    forth:run_mode     [ >r                                       ] ;CASE
    unknown_mode
  ;

  : meta:guard_nonmeta
    [ ( header -- )
      dup forth:handler &handle:normal = [
        &meta:handle_nonmeta swap forth:handler!
      ] ;when
      drop
    ] forth:each_word
  ;

PUBLIC

  : xlatest  adr_xlatest x@ ;
  : xlatest! adr_xlatest x! ;

  STRUCT xheader
    cell: xnext
    cell: xname
    cell: xxt
  END

  0x01 as: immed_flag
  0x02 as: hidden_flag
  0x03 as: flags
  : on  or         ;
  : off invert and ;
  : on!  over x@ swap on  swap x! ; # xadr flag
  : off! over x@ swap off swap x! ; # xadr flag
  : x:hide! xnext hidden_flag on!  ;
  : x:show! xnext hidden_flag off! ;
  : x:hidden? xnext x@ hidden_flag and ;
  : xnext! xnext x! ;
  : xnext  xnext x@ flags off ;

  : xname! xname x! ;
  : xname  xname x@ ;
  : xxt!   xxt   x! ;
  : xxt    xxt   x@ ;

  : x:each_word ( q -- ) # q: ( xheader -- )
    xlatest [ ( q xheader )
      0 [ STOP ] ;CASE
      2dup xnext >r >r
      swap call
      r> r> GO
    ] while
  ;

  : x:words [ xname x>t pr " " pr ] x:each_word cr ;

  : x:find ( name -- xheader yes | no )
    xlatest [ ( s xheader )
      0 [ no STOP ] ;CASE
      2dup xname x>t s= [ nip yes STOP ] ;when
      xnext GO
    ] while
  ;

  : xcreate ( name -- )
    # create xdict entry
    xhere:align!
    xhere swap x:sput xhere:align! # -- &name
    xhere xlatest x, xlatest!      # -- &name
    ( &name   ) x,
    ( xt      ) xhere cell + x,
  ;

  : mcreate ( name -- )
    # create meta-entry
    forth:create
    &mhandle_normal forth:latest forth:handler!
  ;

  : meta:create ( name -- )
    verbose [ dup epr " " epr ] when
    [ xcreate ] [ mcreate ] biq
    xlatest xxt forth:latest forth:xt!
  ;

  : meta:handle_const ( v mode -- )
    forth:compile_mode [ xLIT,, ] ;CASE
    forth:run_mode     [       ] ;CASE
    unknown_mode
  ;

  : meta:create_const ( n name -- )
    # will be patched: LIT v RET 0 => LIT v JMP doconst
    meta:create
    &meta:handle_const forth:latest forth:handler!
    [ xLIT,, xRET, 0 x, ]
    [ forth:latest forth:xt! ] biq
  ;

  ( ----- primitives ----- )

  : PRIMITIVES ( -- n closer ) 0 [ drop ] ;

  : PRIM: ( n closer q name: -- ) # run and compile
    >r over r> swap # n closer q n
    in:read [ "primitive name required" panic ] unless mcreate_prim
    &inc dip
  ;

  : compile_only [ "compile only primitive" panic ] ;

  ( ----- metacompiler ----- )

  : meta:start
    meta:guard_nonmeta
    &meta:num_handler forth:num_handler!
    &meta:amp_handler forth:amp_handler!
    &meta:str_handler forth:str_parser!
    meta:reveal
  ;

  : set_entrypoint ( name -- )
    dup forth:find [ epr " ?(entrypoint)" panic ] unless nip
    forth:xt entrypoint!
  ;

  : meta:finish
    "main" set_entrypoint
    "<info>" prn xinfo
    "<dump>" prn 0 128 xdump
    "<words>" prn x:words
    "out/tmp.ark" save
    "DONE" eprn
    bye
  ;

  : xLIT, xLIT, ;
  : xLIT,, xLIT,, ;
  : xRET, xRET, ;
  : xJMP, xJMP, ;
  : xZJMP, xZJMP, ;

END



( ===== meta words ===== )

PRIMITIVES

  [      ]     PRIM: NOOP
  [ HALT ]     PRIM: HALT
  compile_only PRIM: LIT
  compile_only PRIM: RET

  [ dup  ] PRIM: dup
  [ drop ] PRIM: drop
  [ swap ] PRIM: swap
  [ over ] PRIM: over

  [ +    ] PRIM: +
  [ -    ] PRIM: -
  [ *    ] PRIM: *
  [ /mod ] PRIM: /mod

  [ =  ] PRIM: =
  [ != ] PRIM: !=
  [ >  ] PRIM: >
  [ <  ] PRIM: <

  compile_only PRIM: JMP
  compile_only PRIM: ZJMP

  [ @  ] PRIM: @
  [ !  ] PRIM: !
  [ b@ ] PRIM: b@
  [ b! ] PRIM: b!

  [ and    ] PRIM: and
  [ or     ] PRIM: or
  [ invert ] PRIM: inv
  [ xor    ] PRIM: xoro
  [ lshift ] PRIM: lsft
  [ ashift ] PRIM: asft

  [ io ] PRIM: io

  compile_only PRIM: >r
  compile_only PRIM: r>
  compile_only PRIM: rdrop

  [ sp  ] PRIM: sp
  [ sp! ] PRIM: sp!
  [ rp  ] PRIM: rp
  [ rp! ] PRIM: rp!

END


: M-:
  in:read [ "word name required" panic ] unless
  meta:create
  xlatest x:hide!
  forth:latest forth:hide!
  forth:compile_mode!
;


: M-; <IMMED>
  xRET,
  forth:latest forth:show!
  xlatest x:show!
  forth:run_mode!
;


: M-as: ( n name: -- )
  in:read [ "word name required" panic ] unless
  meta:create_const
;


: M-IF <IMMED> ( -- &back )
  xZJMP, xhere 0 x,
;


: M-ELSE <IMMED> ( &back -- &back2 )
  xJMP, xhere 0 x, swap ( &back2 &back )
  xhere swap x!
;


: M-THEN <IMMED> ( &back -- )
  xhere swap x!
;


: M-AGAIN <IMMED>
  xJMP, xlatest xxt x,
;


: M-[ <IMMED> ( -- &quot &back )
  xJMP, xhere 0 x, xhere swap
;


: M-] <IMMED> ( &quot &back -- )
  xRET, xhere swap x! xLIT,,
;


: x:hide_range ( start -- end )
  # hide start < word <= end
  [ 2dup = [ 2drop STOP ] ;IF
    dup x:hide! xnext GO
  ] while
;


: M-PRIVATE ( -- start closer )
  xlatest [ xlatest x:hide_range ]
;


: M-PUBLIC ( start closer -- start end closer )
  drop xlatest &x:hide_range
;


: M-END <IMMED> ( q -- ) >r ;


: M-<IMMED> <IMMED>
  xlatest x:show!
;


: M-defer: ( name: -- )
  # JMP actual
  in:read [ "word name required" panic ] unless
  meta:create
  xJMP, 0 x,
;


: M-is: ( &actual &defered -- )
  in:read [ "word name required" panic ] unless
  dup x:find [ epr " ?" panic ] unless nip
  xxt
  # replace actual at `JMP (here)`
  cell + x!
;


: M-val: ( name: -- )
  # val:  LIT v RET
  # val!: LIT &v ! RET
  in:read [ "val name required" panic ] unless
  dup meta:create
  xLIT, xhere swap 0 x, xRET, ( &v name )

  dup "!" s:append! meta:create
  xLIT,, &M-! @ x, xRET,
  xlatest xname prn
;


: M-;IF   ";IF not defined yet" panic ; <IMMED> 
: M-;CASE ";CASE not defined yet" panic ; <IMMED>


( ===== metacompile ===== )

#TODO patch x-handlers
#TODO comment (tail of core.f)
#TODO val:

meta:start
include: forth/core.f
meta:finish

