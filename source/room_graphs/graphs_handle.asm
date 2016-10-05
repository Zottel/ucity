;###############################################################################
;
;    BitCity - City building game for Game Boy Color.
;    Copyright (C) 2016 Antonio Nino Diaz (AntonioND/SkyLyrac)
;
;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
;    Contact: antonio_nd@outlook.com
;
;###############################################################################

    INCLUDE "hardware.inc"
    INCLUDE "engine.inc"

;-------------------------------------------------------------------------------

    INCLUDE "room_graphs.inc"

;###############################################################################

    SECTION "Graph Handling Data",WRAM0

;-------------------------------------------------------------------------------

GRAPH_POPULATION_DATA::   DS GRAPH_SIZE
GRAPH_POPULATION_OFFSET:: DS 1 ; Circular buffer start index
GRAPH_POPULATION_SCALE:   DS 1

;###############################################################################

    SECTION "Graph Handling Functions",ROMX

;-------------------------------------------------------------------------------

GraphsClearRecords:: ; Clear WRAM

    ; Total population graph

    ld      hl,GRAPH_POPULATION_DATA
    ld      a,GRAPH_INVALID_ENTRY
    ld      b,GRAPH_SIZE
    call    memset_fast ; a = value    hl = start address    b = size

    xor     a,a
    ld      [GRAPH_POPULATION_OFFSET],a
    ld      [GRAPH_POPULATION_SCALE],a

    ret

;-------------------------------------------------------------------------------

GraphsSaveRecords:: ; Save to SRAM

    ; Enable SRAM

    ld      a,CART_RAM_ENABLE
    ld      [rRAMG],a

    ; Total population graph

    ld      bc,GRAPH_SIZE
    ld      hl,GRAPH_POPULATION_DATA
    ld      de,SAV_GRAPH_POPULATION_DATA
    call    memcopy ; bc = size    hl = source address    de = dest address

    ld      a,[GRAPH_POPULATION_OFFSET]
    ld      [SAV_GRAPH_POPULATION_OFFSET],a

    ld      a,[GRAPH_POPULATION_SCALE]
    ld      [SAV_GRAPH_POPULATION_SCALE],a

    ; Disable SRAM

    ld      a,CART_RAM_DISABLE
    ld      [rRAMG],a

    ret

;-------------------------------------------------------------------------------

GraphsLoadRecords:: ; Load from SRAM

    ; Enable SRAM

    ld      a,CART_RAM_ENABLE
    ld      [rRAMG],a

    ; Total population graph

    ld      bc,GRAPH_SIZE
    ld      de,GRAPH_POPULATION_DATA
    ld      hl,SAV_GRAPH_POPULATION_DATA
    call    memcopy ; bc = size    hl = source address    de = dest address

    ld      a,[SAV_GRAPH_POPULATION_OFFSET]
    ld      [GRAPH_POPULATION_OFFSET],a

    ld      a,[SAV_GRAPH_POPULATION_SCALE]
    ld      [GRAPH_POPULATION_SCALE],a

    ; Disable SRAM

    ld      a,CART_RAM_DISABLE
    ld      [rRAMG],a

    ret

;-------------------------------------------------------------------------------

GraphHandleRecords::

    ; This calls the individual graph handling functions

    call    GraphTotalPopulationAddRecord

    ret

;-------------------------------------------------------------------------------

SRL32: ; a = shift value, bcde = value (B = MSB, E = LSB), return value = bcde

    cp      a,32 ; cy = 1 if 32 > a  (a <= 31)
    jr      c,.not_trivial
        ld      bc,0 ; shift value too big, just return 0!
        ld      de,0
        ret
.not_trivial:

    bit     4,a
    jr      z,.not_16
        LD_DE_BC ; Shift by 16
        ld      bc,0
.not_16:
    bit     3,a
    jr      z,.not_8
        ld      e,d ; Shift by 8
        ld      d,c
        ld      c,b
        ld      b,0
.not_8:
    bit     2,a
    jr      z,.not_4
        REPT    4 ; Shift by 4
        sra     b
        rr      c
        rr      d
        rr      e
        ENDR
.not_4:
    bit     1,a
    jr      z,.not_2
        REPT    2 ; Shift by 2
        sra     b
        rr      c
        rr      d
        rr      e
        ENDR
.not_2:
    bit     0,a
    jr      z,.not_1
        sra     b ; Shift by 1
        rr      c
        rr      d
        rr      e
.not_1:

    ret

;-------------------------------------------------------------------------------

GraphTotalPopulationAddRecord:

    ; Calculate value
    ; ---------------

.loop_calculate:

        ld      hl,population_total ; LSB first, 4 bytes
        ld      a,[hl+]
        ld      e,a
        ld      a,[hl+]
        ld      d,a
        ld      a,[hl+]
        ld      c,a
        ld      b,[hl]

        ld      a,[GRAPH_POPULATION_SCALE]

        call    SRL32 ; a = shift value, bcde = value to shift

        ld      a,e
        and     a,$80
        or      a,d
        or      a,c
        or      a,b ; check if it fits in 127 (0000007F)
        jr      z,.end_loop

        ; If it is bigger than the scale, change scale and scale stored data

        ld      hl,GRAPH_POPULATION_SCALE
        inc     [hl] ; no need to check, we are only shifting a 32 bit value
        ; so a shift by 32 should make anything fit in the graph.

        ; Divide by 2 the stored data

        ld      b,GRAPH_SIZE
        ld      hl,GRAPH_POPULATION_DATA
.loop_scale_down:
        sra     [hl] ; GRAPH_INVALID_ENTRY == -1, it will be preserved
        inc     hl
        dec     b
        jr      nz,.loop_scale_down

    jr      .loop_calculate

.end_loop:

    ld      b,e ; b = value to save

    ; Finally, save this value
    ; ------------------------

    ld      a,[GRAPH_POPULATION_OFFSET]
    ld      e,a
    ld      d,0
    ld      hl,GRAPH_POPULATION_DATA
    add     hl,de ; hl = pointer to next entry

    ld      [hl],b

    ld      a,[GRAPH_POPULATION_OFFSET]
    inc     a
    and     a,GRAPH_SIZE-1
    ld      [GRAPH_POPULATION_OFFSET],a

    ret

;###############################################################################