require: lib/core.f
require: lib/mgui.f



( ===== global ===== )

256 as: spr_max
8 as: spr_w
8 as: spr_h
spr_w spr_h * as: spr_size

8 as: padding

val: selected
val: spraddr

val: sprbase
basic.spr filedata sprbase!

: selected!
  dup selected!
  spr_size * sprbase + spraddr! ;

0 selected!



( ===== showcase ===== )

MODULE

  8 as: spr/line
  8 as: lines
  spr/line lines * as: spr/screen
  spr_max lines / as: max_lines
  1 as: border

  spr_w spr/line * as: width
  spr_h lines *    as: height

  padding border + as: left
  left width +     as: right
  padding border + as: top
  top height +     as: bottom

  left   border -     as: bl
  top    border -     as: bt
  width  border 2 * + as: bw
  height border 2 * + as: bh

  bl                as: idx
  bt bh + padding + as: idy

  val: row  val: col
  val: x  val: y

  val: basespr  ( start sprite on showcase )
  val: rowspr   ( start sprite on row )
  val: spr

  : basealign ( i -- i ) spr/line / spr/line * ;
  : basespr! ( i -- ) spr_max + spr_max mod basealign basespr! ;
  : basespr+! ( n -- ) basespr swap + basespr! ;
  : basespr-! ( n -- ) basespr swap - basespr! ;

  : row! ( row -- )
    dup row!
    dup spr/line * basespr + spr_max mod rowspr!
    spr_h * top + y!
  ;

  : col! ( col -- )
    dup col!
    dup rowspr + spr!
    spr_w * left + x!
  ;

  ( scroll buttons )

  bl bw + 4 +  as: btn_left
  padding      as: btn_top
  padding bh + as: btn_bottom

  : scrollbtn ( y spr q -- )
    >r >r >r 0 btn_left r> r> r> sprbtn:create drop
  ;

  : current! selected spr/line 3 * - basespr! ;

  btn_top         0x8A [ drop spr/screen basespr-! ] scrollbtn
  btn_top    9  + 0x8E [ drop spr/line   basespr-! ] scrollbtn
  btn_top    25 + 0x90 [ drop current!             ] scrollbtn
  btn_bottom 17 - 0x8F [ drop spr/line   basespr+! ] scrollbtn
  btn_bottom 8  - 0x8B [ drop spr/screen basespr+! ] scrollbtn

  ( draw )

  : draw_cursor
    3 ppu:color!
    x border - y border - 
    spr_w border + spr_h border +
    rect
  ;

  : draw_showcase
    8 [ row!
      8 [ col!
        spr sprite:i!
        x y sprite:plot
        spr selected = IF draw_cursor THEN
      ] for
    ] for
  ;

  : draw_border 1 ppu:color! bl bt bw bh rect ;

  : draw_id selected idx idy put_ff ;

  ( select )

  : handle_select
    mouse:lp not IF RET THEN
    mouse:x mouse:y left top width height hover_rect? not IF RET THEN
    mouse:x left - spr_w /   mouse:y top - spr_h /   ( col row )
    spr/line * + basespr + spr_max mod selected!
  ;

---EXPOSE---

  : showcase:draw ( -- )
    handle_select
    draw_border
    draw_showcase
    draw_id
  ;

  btn_left spr_w + as: showcase:right

END



( ===== editor ===== )

MODULE

  spr_w dup * as: width
  spr_h dup * as: height
  
  1 as: border
  
  padding 3 * as: leftpad
  
  padding                  border + as: top
  showcase:right leftpad + border + as: left
  left width +                      as: right
  top height +                      as: bottom

  val: x  val: y
  val: col val: row
  val: adr
  : dot  adr b@ ;
  : dot! adr b! ;
  
  : row!  dup row!  spr_h * top + y!  ;
  : col!
    dup col!
    dup spr_w * left + x!
    row spr_w * + spraddr + adr!
  ;

  top  border - as: bt
  left border - as: bl
  width  border 2 * + as: bw
  height border 2 * + as: bh
  
  : draw_border
    1 ppu:color!
    bl bt bw bh rect
  ;
  
  : draw_canvas
    1 ppu:color!
    spr_h [ row!
      spr_w [ col!
        dot sprite:i!
        x y ppu:plot
        x y sprite:plot
      ] for
    ] for
  ;
  
  bl as: prv_x
  bt bh + 4 + as: prv_y
  
  : draw_preview
    selected sprite:i!
    prv_x prv_y sprite:plot
  ;

  ( ----- handle mouse ----- )

  val: pressed
  val: color  ( 0-3 ) 3 color!
  val: curcol ( current color )

  : hover? mouse:x mouse:y left top width height hover_rect? ;

  : where
    mouse:y top  - spr_h / row!
    mouse:x left - spr_w / col!
  ;

  : press
    pressed IF RET THEN yes pressed!
    dot IF 0 ELSE color THEN curcol!
  ;

  : paint curcol dot! ;

  : handle_mouse
    mouse:lp not IF no pressed! RET THEN
    hover? not IF RET THEN
    where press paint
  ;
  
---EXPOSE---

  : editor:draw
    handle_mouse
    draw_border
    draw_canvas
    draw_preview
  ;
  
END



30 [
  mgui:update
  showcase:draw
  editor:draw
]  draw_loop:register!

[ ( wait ) GO ] while
