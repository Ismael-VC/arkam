: <IMMED> &handle:immed forth:latest forth:handler! ; <IMMED>


: ?h <IMMED> "HERE" prn ; ( debug )


: # <IMMED>
  ( skip line comment )
  [ in:take
    0  [ STOP ] ;CASE
    10 [ STOP ] ;CASE
    drop GO
  ] while
;


( --- stack --- )

: tuck ( a b -- b a b ) swap over ;
: ?dup ( a -- a a | 0 ) dup IF dup THEN ;

: pullup   ( a b c -- b c a ) >r swap r> swap ;
: pushdown ( b c a -- a b c ) swap >r swap r> ;


( --- shorthand/util --- )
: as: const: ;

: forth:handle_mode ( xt state q_run q_compile -- .. )
  # q: ( xt -- )
  pullup
  forth:run_mode     [ drop >r ] ;CASE
  forth:compile_mode [ nip  >r ] ;CASE
  ? drop "Unknown mode" panic
;


( --- Generic structure closer --- )
: END <IMMED> ( q -- ) >r ;



( ----- Module ----- )

: MODULE ( -- start start closer )
  forth:latest dup
  [ ( start end -- )
    [ 2dup = [ 2drop STOP ] ;IF
      dup forth:hide! forth:next GO
    ] while
  ]
;

: ---EXPOSE--- ( start start closer -- start latest closer )
  nip forth:latest swap ;



( ----- string ----- )


: s:append! ( dst what -- )
  ( no check )
  >r [ dup b@ IF inc GO ELSE STOP THEN ] while r> ( dst what )
  [ 2dup b@ swap over swap b!
    IF &inc bia GO ELSE 2drop STOP THEN
  ] while
;

: s:append ( dst what max -- ? )
  # max includes null termination
  ( check )
  >r 2dup &s:len bia + inc r>
  > [ 2drop ng ] ;IF
  s:append! ok
;


: s:check ( str max -- str ok? )
  # check length
  # max includes null termination
  over s:len 1 + >=
;



( ----- val ----- )

MODULE 

  32 const: len
  len allot const: buf
  len 1 - const: max
  
  : check ( name -- name )
    dup s:len max > IF epr " too long" panic THEN
  ;

  # xt is address of cell that contains a value.
  # for referencing(&valname), VAL: uses their own handlers

  : handle_getter ( xt state -- )
    [ @                                         ]
    [ "LIT" forth:compile, , "@" forth:compile, ]
    forth:handle_mode
  ;
  
  : create_getter ( addr -- )
    buf forth:create
    forth:latest forth:xt!
    &handle_getter forth:latest forth:handler!
  ;

  : handle_setter
    [ !                                         ]
    [ "LIT" forth:compile, , "!" forth:compile, ]
    forth:handle_mode
  ;

  : create_setter ( addr -- )
    buf "!" max s:append drop
    buf forth:create
    forth:latest forth:xt!
    &handle_setter forth:latest forth:handler!
  ;

---EXPOSE---
  
  : val: ( -- )
    in:read not IF "val name required" panic THEN
    max s:check [ epr " ...too long" panic ] unless
    buf s:copy
    here:align! here 0 , dup
    create_getter
    create_setter
  ;
  
END



( ----- words ----- )

: words
  forth:latest [
    0 [ STOP ] ;CASE
    dup forth:hidden? not IF
      dup forth:name pr space
    THEN
    forth:next GO
  ] while
  cr
;


( ----- char ----- )

: CHAR: <IMMED>
  in:read [ "a char required" panic ] unless
  b@
  forth:mode
  forth:compile_mode [ "LIT" forth:compile, , ] ;CASE
  forth:run_mode     [ ( noop )               ] ;CASE
  ? "unknown mode" panic
;


( ----- struct ----- )

MODULE

  : close ( -- word offset ) swap forth:xt! ;

---EXPOSE---

  : STRUCT ( -- word offset q )
    in:read [ "struct name required" panic ] unless
    forth:create
    &handle:data forth:latest forth:handler!
    forth:latest 0 &close
  ;
  
  : field: ( offset q n -- offset+n q)
    in:read [ "field name required" panic ] unless
    forth:create
    swap >r over
    "LIT" forth:compile, , "+" forth:compile, "RET" forth:compile,
    + r>
  ;
  
END



( ----- loadfile ----- )

# loadfile ( path -- addr )
# loadfile: ( :path -- addr )
# addr:
#   0x00 size
#   0x04 data...
#        0000 ( null terminated, aligned )


MODULE

  val: id
  val: addr
  val: size

---EXPOSE---

  : loadfile ( path -- addr )
    "rb" file:open! id!
    id file:size size!
    here addr!
    size ,
    here size id file:read!
    here size + here!
    0 b, here:align!
    id file:close!
    addr
  ;
  
  : loadfile: ( :path -- addr )
    in:read [ "file name required" ] unless loadfile ;

  : filesize @ ;      # & -- n 
  : filedata cell + ; # & -- &data
  
END
