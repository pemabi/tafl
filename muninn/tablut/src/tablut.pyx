# cython: language_level=3
#==============================================================================
# Imports and Type Declarations
#==============================================================================
# TODO: refactor magics and Bitboard Masks to 3x3s. Possible create Blocker Masks dynamically at start

from libc.stdint cimport uint64_t, uint8_t, uint16_t
from cpython.dict cimport PyDict_SetItem, PyDict_GetItem
from cpython.object cimport PyObject
from tqdm import tqdm
from libc.stdlib cimport malloc, free
from libc.stdlib cimport rand
from libc.stddef cimport size_t
import random
from typing import List
from cpython cimport array
import array
from libc.math cimport exp
import sys
cimport cython
from libc.math cimport log2 as clog2
from libc.time cimport clock, CLOCKS_PER_SEC
from libc.stdio cimport printf


# TO UPDATE CYTHON CODE USE BELOW
# python setup.py build_ext --inplace

#==============================================================================
# Bitboard Struct and Constants Definition
#==============================================================================
ZERO = <uint64_t>0
THRONE = <uint64_t>0x0000010000000000
THRONE_MASK = <uint64_t>0x7FFFFEFFFFFFFFFF
KING_MOVE_FLAG = <uint16_t>0x4000

cdef struct Bitboard:
    uint64_t low
    uint64_t high

cdef Bitboard EMPTY_BITBOARD = Bitboard(ZERO, ZERO)
cdef Bitboard FULL_BITBOARD = Bitboard(0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF)

ctypedef Bitboard (*bb_func)(Bitboard, int)

cdef Bitboard[81] BLOCKER_MASK = [  # TODO: potentially generate this 1x at runtime - so cheap and just takes up space
    Bitboard(low = 0x00402010080402FE, high = 0x0000000000000001),
    Bitboard(low = 0x00804020100804FC, high = 0x0000000000000002),
    Bitboard(low = 0x01008040201008FA, high = 0x0000000000000004),
    Bitboard(low = 0x02010080402010F6, high = 0x0000000000000008),
    Bitboard(low = 0x04020100804020EE, high = 0x0000000000000010),
    Bitboard(low = 0x08040201008040DE, high = 0x0000000000000020),
    Bitboard(low = 0x10080402010080BE, high = 0x0000000000000040),
    Bitboard(low = 0x201008040201007E, high = 0x0000000000000080),
    Bitboard(low = 0x40201008040200FE, high = 0x0000000000000100),
    Bitboard(low = 0x004020100805FC00, high = 0x0000000000000001),
    Bitboard(low = 0x008040201009F800, high = 0x0000000000000002),
    Bitboard(low = 0x010080402011F400, high = 0x0000000000000004),
    Bitboard(low = 0x020100804021EC00, high = 0x0000000000000008),
    Bitboard(low = 0x040201008041DC00, high = 0x0000000000000010),
    Bitboard(low = 0x080402010081BC00, high = 0x0000000000000020),
    Bitboard(low = 0x1008040201017C00, high = 0x0000000000000040),
    Bitboard(low = 0x201008040200FC00, high = 0x0000000000000080),
    Bitboard(low = 0x402010080401FC00, high = 0x0000000000000100),
    Bitboard(low = 0x004020100BF80200, high = 0x0000000000000001),
    Bitboard(low = 0x0080402013F00400, high = 0x0000000000000002),
    Bitboard(low = 0x0100804023E80800, high = 0x0000000000000004),
    Bitboard(low = 0x0201008043D81000, high = 0x0000000000000008),
    Bitboard(low = 0x0402010083B82000, high = 0x0000000000000010),
    Bitboard(low = 0x0804020103784000, high = 0x0000000000000020),
    Bitboard(low = 0x1008040202F88000, high = 0x0000000000000040),
    Bitboard(low = 0x2010080401F90000, high = 0x0000000000000080),
    Bitboard(low = 0x4020100803FA0000, high = 0x0000000000000100),
    Bitboard(low = 0x00402017F0040200, high = 0x0000000000000001),
    Bitboard(low = 0x00804027E0080400, high = 0x0000000000000002),
    Bitboard(low = 0x01008047D0100800, high = 0x0000000000000004),
    Bitboard(low = 0x02010087B0201000, high = 0x0000000000000008),
    Bitboard(low = 0x0402010770402000, high = 0x0000000000000010),
    Bitboard(low = 0x08040206F0804000, high = 0x0000000000000020),
    Bitboard(low = 0x10080405F1008000, high = 0x0000000000000040),
    Bitboard(low = 0x20100803F2010000, high = 0x0000000000000080),
    Bitboard(low = 0x40201007F4020000, high = 0x0000000000000100),
    Bitboard(low = 0x00402FE008040200, high = 0x0000000000000001),
    Bitboard(low = 0x00804FC010080400, high = 0x0000000000000002),
    Bitboard(low = 0x01008FA020100800, high = 0x0000000000000004),
    Bitboard(low = 0x02010F6040201000, high = 0x0000000000000008),
    Bitboard(low = 0x04020EE080402000, high = 0x0000000000000010),
    Bitboard(low = 0x08040DE100804000, high = 0x0000000000000020),
    Bitboard(low = 0x10080BE201008000, high = 0x0000000000000040),
    Bitboard(low = 0x201007E402010000, high = 0x0000000000000080),
    Bitboard(low = 0x40200FE804020000, high = 0x0000000000000100),
    Bitboard(low = 0x005FC01008040200, high = 0x0000000000000001),
    Bitboard(low = 0x009F802010080400, high = 0x0000000000000002),
    Bitboard(low = 0x011F404020100800, high = 0x0000000000000004),
    Bitboard(low = 0x021EC08040201000, high = 0x0000000000000008),
    Bitboard(low = 0x041DC10080402000, high = 0x0000000000000010),
    Bitboard(low = 0x081BC20100804000, high = 0x0000000000000020),
    Bitboard(low = 0x1017C40201008000, high = 0x0000000000000040),
    Bitboard(low = 0x200FC80402010000, high = 0x0000000000000080),
    Bitboard(low = 0x401FD00804020000, high = 0x0000000000000100),
    Bitboard(low = 0x3F80201008040200, high = 0x0000000000000001),
    Bitboard(low = 0x3F00402010080400, high = 0x0000000000000002),
    Bitboard(low = 0x3E80804020100800, high = 0x0000000000000004),
    Bitboard(low = 0x3D81008040201000, high = 0x0000000000000008),
    Bitboard(low = 0x3B82010080402000, high = 0x0000000000000010),
    Bitboard(low = 0x3784020100804000, high = 0x0000000000000020),
    Bitboard(low = 0x2F88040201008000, high = 0x0000000000000040),
    Bitboard(low = 0x1F90080402010000, high = 0x0000000000000080),
    Bitboard(low = 0x3FA0100804020000, high = 0x0000000000000100),
    Bitboard(low = 0x0040201008040200, high = 0x00000000000000FE),
    Bitboard(low = 0x0080402010080400, high = 0x00000000000000FC),
    Bitboard(low = 0x0100804020100800, high = 0x00000000000000FA),
    Bitboard(low = 0x0201008040201000, high = 0x00000000000000F6),
    Bitboard(low = 0x0402010080402000, high = 0x00000000000000EE),
    Bitboard(low = 0x0804020100804000, high = 0x00000000000000DE),
    Bitboard(low = 0x1008040201008000, high = 0x00000000000000BE),
    Bitboard(low = 0x2010080402010000, high = 0x000000000000007E),
    Bitboard(low = 0x4020100804020000, high = 0x00000000000000FE),
    Bitboard(low = 0x0040201008040200, high = 0x000000000001FC01),
    Bitboard(low = 0x0080402010080400, high = 0x000000000001F802),
    Bitboard(low = 0x0100804020100800, high = 0x000000000001F404),
    Bitboard(low = 0x0201008040201000, high = 0x000000000001EC08),
    Bitboard(low = 0x0402010080402000, high = 0x000000000001DC10),
    Bitboard(low = 0x0804020100804000, high = 0x000000000001BC20),
    Bitboard(low = 0x1008040201008000, high = 0x0000000000017C40),
    Bitboard(low = 0x2010080402010000, high = 0x000000000000FC80),
    Bitboard(low = 0x4020100804020000, high = 0x000000000001FD00)]

cdef inline Bitboard get_blocker_mask(int index):
    """
    Returns relevant blocker mask for a given square.
    """
    return Bitboard(BLOCKER_MASK[index].low, BLOCKER_MASK[index].high)

cdef inline Bitboard get_blockers(Bitboard occupancy, int square):
    """
    Returns relevant blockers for a given square and Bitboard. Use with occupancy Bitboard to calculate moves.
    """
    return and_board(occupancy, BLOCKER_MASK[square])

cdef int[81] BLOCKER_BITS = [  # represents number of blockers in blocker set for each square
    14, 13, 13, 13, 13, 13, 13, 13, 14,
    13, 12, 12, 12, 12, 12, 12, 12, 13,
    13, 12, 12, 12, 12, 12, 12, 12, 13,
    13, 12, 12, 12, 12, 12, 12, 12, 13,
    13, 12, 12, 12, 12, 12, 12, 12, 13,
    13, 12, 12, 12, 12, 12, 12, 12, 13,
    13, 12, 12, 12, 12, 12, 12, 12, 13,
    13, 12, 12, 12, 12, 12, 12, 12, 13,
    14, 13, 13, 13, 13, 13, 13, 13, 14]

# Huge shout out to Apery for validating my efforts here - following their lead by increasize index size for squares 17 and 53
cdef int[81] SHIFT_BITS = [  # represents bits we shift when calculating move index. Generally follows pattern 64 - BLOCKER_BITS[i]
    50, 51, 51, 51, 51, 51, 51, 51, 50,
    51, 52, 52, 52, 52, 52, 52, 52, 50, # [17]: 51 -> 50
    51, 52, 52, 52, 52, 52, 52, 52, 51,
    51, 52, 52, 52, 52, 52, 52, 52, 51,
    51, 52, 52, 52, 52, 52, 52, 52, 51,
    51, 52, 52, 52, 52, 52, 52, 52, 50, # [53]: 51 -> 50
    51, 52, 52, 52, 52, 52, 52, 52, 51,
    51, 52, 52, 52, 52, 52, 52, 52, 51,
    50, 51, 51, 51, 51, 51, 51, 51, 50]

cdef uint64_t[81] MAGIC = [
    0x0040001141090900, 0x10A0000A00044080, 0x04C004000080A080,
    0x00800104102744C0, 0x008000860A122020, 0x4380004500200410,
    0x4280010010040908, 0x0040004808080044, 0x804000088800889A,
    0x0010200001020001, 0x006110000D000880, 0x9000280100400080,
    0x9102200200004001, 0x2800900080020008, 0x0000A00080001001,
    0x0200100800100002, 0x1500601000080004, 0x0100440022084012,  # square 17
    0x8010145000040900, 0x0430020800121040, 0x4444106001010006,
    0x0C04001000440040, 0x14C400200100220A, 0x2682001000200265,
    0x00800C2000420808, 0x3440041002080004, 0x41C0001000020082,
    0xA010205228000300, 0x0020040024000080, 0x0591042820004801,
    0x0004002088008001, 0x021400085000A042, 0x3400004004020008,
    0x10800900B0008808, 0x0400400008040004, 0x094000C828000082,
    0x121A100002440001, 0x0083100042080041, 0x1000080080010020,
    0x82C0020008440040, 0xA002001000240020, 0x0102001000140008,
    0x0200100010020004, 0x0040042000340004, 0x0040000504040022,
    0x0020001042009200, 0x4020080001004900, 0x1000080100400080,
    0x4C00040000800201, 0x2020081010008004, 0x0500008000400201,
    0x0100010040000402, 0x2000800010000601, 0x001001010000800A,  # square 53
    0x0020007000090045, 0x4000A0B841013402, 0x210830010A001402,
    0x0944030420028104, 0x000400100840005B, 0x2002001000200005,
    0x00800080004048D2, 0x13220440C8184028, 0x4028998110120204,
    0x034000840C000C69, 0x00A0040004000080, 0x0080028801081080,
    0x4040010100040040, 0x0240010000240020, 0x4140010000901001,
    0x30800046C0002102, 0x00C0004000180009, 0x204000084244000A,
    0x0004200001252900, 0x0504900002000840, 0x000A200101000280,
    0x0009200085000060, 0x81012000A44000A0, 0x840A400100101110,
    0x0681200210200024, 0x8006200210000904, 0xA000200001224282]

def get_magic_list():
    return [x for x in MAGIC]

cdef Bitboard[81] ATTACK_MASKS = [
Bitboard(low = 0x0000000000040004, high = 0x0000000000000000),
Bitboard(low = 0x0000000000080008, high = 0x0000000000000000),
Bitboard(low = 0x0000000000100011, high = 0x0000000000000000),
Bitboard(low = 0x0000000000200022, high = 0x0000000000000000),
Bitboard(low = 0x0000000000400044, high = 0x0000000000000000),
Bitboard(low = 0x0000000000800088, high = 0x0000000000000000),
Bitboard(low = 0x0000000001000110, high = 0x0000000000000000),
Bitboard(low = 0x0000000002000020, high = 0x0000000000000000),
Bitboard(low = 0x0000000004000040, high = 0x0000000000000000),
Bitboard(low = 0x0000000008000800, high = 0x0000000000000000),
Bitboard(low = 0x0000000010001000, high = 0x0000000000000000),
Bitboard(low = 0x0000000020002200, high = 0x0000000000000000),
Bitboard(low = 0x0000000040004400, high = 0x0000000000000000),
Bitboard(low = 0x0000000080008800, high = 0x0000000000000000),
Bitboard(low = 0x0000000100011000, high = 0x0000000000000000),
Bitboard(low = 0x0000000200022000, high = 0x0000000000000000),
Bitboard(low = 0x0000000400004000, high = 0x0000000000000000),
Bitboard(low = 0x0000000800008000, high = 0x0000000000000000),
Bitboard(low = 0x0000001000100001, high = 0x0000000000000000),
Bitboard(low = 0x0000002000200002, high = 0x0000000000000000),
Bitboard(low = 0x0000004000440004, high = 0x0000000000000000),
Bitboard(low = 0x0000008000880008, high = 0x0000000000000000),
Bitboard(low = 0x0000010001100010, high = 0x0000000000000000),
Bitboard(low = 0x0000020002200020, high = 0x0000000000000000),
Bitboard(low = 0x0000040004400040, high = 0x0000000000000000),
Bitboard(low = 0x0000080000800080, high = 0x0000000000000000),
Bitboard(low = 0x0000100001000100, high = 0x0000000000000000),
Bitboard(low = 0x0000200020000200, high = 0x0000000000000000),
Bitboard(low = 0x0000400040000400, high = 0x0000000000000000),
Bitboard(low = 0x0000800088000800, high = 0x0000000000000000),
Bitboard(low = 0x0001000110001000, high = 0x0000000000000000),
Bitboard(low = 0x0002000220002000, high = 0x0000000000000000),
Bitboard(low = 0x0004000440004000, high = 0x0000000000000000),
Bitboard(low = 0x0008000880008000, high = 0x0000000000000000),
Bitboard(low = 0x0010000100010000, high = 0x0000000000000000),
Bitboard(low = 0x0020000200020000, high = 0x0000000000000000),
Bitboard(low = 0x0040004000040000, high = 0x0000000000000000),
Bitboard(low = 0x0080008000080000, high = 0x0000000000000000),
Bitboard(low = 0x0100011000100000, high = 0x0000000000000000),
Bitboard(low = 0x0200022000200000, high = 0x0000000000000000),
Bitboard(low = 0x0400044000400000, high = 0x0000000000000000),
Bitboard(low = 0x0800088000800000, high = 0x0000000000000000),
Bitboard(low = 0x1000110001000000, high = 0x0000000000000000),
Bitboard(low = 0x2000020002000000, high = 0x0000000000000000),
Bitboard(low = 0x4000040004000000, high = 0x0000000000000000),
Bitboard(low = 0x0000800008000000, high = 0x0000000000000001),
Bitboard(low = 0x0001000010000000, high = 0x0000000000000002),
Bitboard(low = 0x0002200020000000, high = 0x0000000000000004),
Bitboard(low = 0x0004400040000000, high = 0x0000000000000008),
Bitboard(low = 0x0008800080000000, high = 0x0000000000000010),
Bitboard(low = 0x0011000100000000, high = 0x0000000000000020),
Bitboard(low = 0x0022000200000000, high = 0x0000000000000040),
Bitboard(low = 0x0004000400000000, high = 0x0000000000000080),
Bitboard(low = 0x0008000800000000, high = 0x0000000000000100),
Bitboard(low = 0x0100001000000000, high = 0x0000000000000200),
Bitboard(low = 0x0200002000000000, high = 0x0000000000000400),
Bitboard(low = 0x0440004000000000, high = 0x0000000000000800),
Bitboard(low = 0x0880008000000000, high = 0x0000000000001000),
Bitboard(low = 0x1100010000000000, high = 0x0000000000002000),
Bitboard(low = 0x2200020000000000, high = 0x0000000000004000),
Bitboard(low = 0x4400040000000000, high = 0x0000000000008000),
Bitboard(low = 0x0800080000000000, high = 0x0000000000010000),
Bitboard(low = 0x1000100000000000, high = 0x0000000000020000),
Bitboard(low = 0x0000200000000000, high = 0x0000000000000004),
Bitboard(low = 0x0000400000000000, high = 0x0000000000000008),
Bitboard(low = 0x0000800000000000, high = 0x0000000000000011),
Bitboard(low = 0x0001000000000000, high = 0x0000000000000022),
Bitboard(low = 0x0002000000000000, high = 0x0000000000000044),
Bitboard(low = 0x0004000000000000, high = 0x0000000000000088),
Bitboard(low = 0x0008000000000000, high = 0x0000000000000110),
Bitboard(low = 0x0010000000000000, high = 0x0000000000000020),
Bitboard(low = 0x0020000000000000, high = 0x0000000000000040),
Bitboard(low = 0x0040000000000000, high = 0x0000000000000800),
Bitboard(low = 0x0080000000000000, high = 0x0000000000001000),
Bitboard(low = 0x0100000000000000, high = 0x0000000000002200),
Bitboard(low = 0x0200000000000000, high = 0x0000000000004400),
Bitboard(low = 0x0400000000000000, high = 0x0000000000008800),
Bitboard(low = 0x0800000000000000, high = 0x0000000000011000),
Bitboard(low = 0x1000000000000000, high = 0x0000000000022000),
Bitboard(low = 0x2000000000000000, high = 0x0000000000004000),
Bitboard(low = 0x4000000000000000, high = 0x0000000000008000)]

cdef inline Bitboard get_attack_allies(Bitboard allies, int square):
    """
    Returns relevant supporting allies in potenital attack squares for a given square and Bitboard. Use with allied Bitboard to calculate attacked squares.
    """
    return and_board(allies, ATTACK_MASKS[square])

cdef int[81] ATTACK_BITS = [
    2, 2, 3, 3, 3, 3, 3, 2, 2,
    2, 2, 3, 3, 3, 3, 3, 2, 2,
    3, 3, 4, 4, 4, 4, 4, 3, 3,
    3, 3, 4, 4, 4, 4, 4, 3, 3,
    3, 3, 4, 4, 4, 4, 4, 3, 3,
    3, 3, 4, 4, 4, 4, 4, 3, 3,
    3, 3, 4, 4, 4, 4, 4, 3, 3,
    2, 2, 3, 3, 3, 3, 3, 2, 2,
    2, 2, 3, 3, 3, 3, 3, 2, 2
]

cdef int[81] ATTACK_SHIFT_BITS = [
    62, 62, 61, 61, 61, 61, 61, 62, 62,
    62, 62, 61, 61, 61, 61, 61, 62, 62,
    61, 61, 60, 60, 60, 60, 60, 61, 61,
    61, 61, 60, 60, 60, 60, 60, 61, 61,
    61, 61, 60, 60, 60, 60, 60, 61, 61,
    61, 61, 60, 60, 60, 60, 60, 61, 61,
    61, 61, 60, 60, 60, 60, 60, 61, 61,
    62, 62, 61, 61, 61, 61, 61, 62, 62,
    62, 62, 61, 61, 61, 61, 61, 62, 62
]

cdef uint64_t[81] ATTACK_MAGICS = [
    0x104820A102002160, 0x10A00D0880000001, 0x4201482800020000,
    0x2405417000002014, 0x0960020000800000, 0x4848030050058206,
    0x0340808058394004, 0x4D2130A401002801, 0x11D0002050002060,
    0x03308C2820801811, 0x0004071880000000, 0x0821020440002004,
    0x040A300112900900, 0x0410402090061200, 0x0042500C88004002,
    0x2004680030004200, 0x5082188010520000, 0x0C09306428200003,
    0x2010040C880A1200, 0x2100042061128010, 0x10444A00004200C0,
    0x0424090000201020, 0x0611018010408002, 0x0221409000428821,
    0x02001148C0100000, 0x008C005000102000, 0x0848028201024000,
    0x2044030A90010000, 0x600804824041082E, 0x6008003020004820,
    0x09020234190080A0, 0x0022040C08805000, 0x0020404120000800,
    0x0000201048049008, 0x0500404898403210, 0x0005400E18002202,
    0x0400E08800821140, 0x8400041A20800120, 0x8800080807232041,
    0x4220441011080021, 0x0000008022040250, 0x0001030021246009,
    0x000008100C28088C, 0x01000C4060208001, 0x0401220E09600C07,
    0x400020C520010081, 0x200004080C122100, 0x2040020108C20800,
    0x02000006020C9188, 0x09020208801104A0, 0x1401010144011200,
    0x004A000014404200, 0x004080A130642000, 0x022BB34010800820,
    0x001C00A008000841, 0x908C0060040C0826, 0x011010C10100A984,
    0x8008000100208048, 0x01008500808400A4, 0x50010824D4081841,
    0x01C0400C00442112, 0x1001218401084810, 0x0008414044048002,
    0x161000800804048A, 0x4B10005008020134, 0x2404028020030100,
    0x421000020040A110, 0x49201A0504004002, 0x690210000005A941,
    0x0820800AE3040A00, 0x5409140408110640, 0x2284C28042003262,
    0x0211330000000910, 0x00080A0808002094, 0x0012028A22000088,
    0x4009244408020041, 0x000900A10000010A, 0x0104900200444004,
    0x4801248000000009, 0x400529800C000004, 0x020B1D0205680001]

#==============================================================================
# Bit Manipulation Macros
#==============================================================================
cdef inline void set_bit(Bitboard* board, int index):
    """
    Sets bit at square index 0-80 to 1.
    """
    if 0 <= index < 63:
        board.low |= (<uint64_t>1) << index  # NOTE that I do not need to dereference pointers in this case. When passing an object pointer, Cython auto dereferences when I access its members
    elif 63 <= index < 81:
        board.high |= (<uint64_t>1) << (index - 63)
    else:
        raise ValueError("Bit index must be between 0 and 80")

cdef inline bint is_bit_set(Bitboard* board, int index):
    """
    Returns True if bit at square index 0-80 is set, else False.
    """
    if 0 <= index < 63:
        return bool(board.low & ((<uint64_t>1) << index))
    elif 63 <= index < 81:
        return bool(board.high & ((<uint64_t>1) << (index - 63)))
    else:
        raise ValueError("Bit index must be between 0 and 80")

cdef inline bint is_bit_set_2(Bitboard board, int index):
    """
    Returns True if bit at square index 0-80 is set, else False.
    """
    if 0 <= index < 63:
        return bool(board.low & ((<uint64_t>1) << index))
    elif 63 <= index < 81:
        return bool(board.high & ((<uint64_t>1) << (index - 63)))
    else:
        raise ValueError("Bit index must be between 0 and 80")

cdef void clear_bit(Bitboard* board, int index):
    """
    Pops bit at square index 0-80.
    """
    if 0 <= index < 63:
        board.low &= ~((<uint64_t>1) << index)
    elif 63 <= index < 81:
        board.high &= ~((<uint64_t>1) << (index - 63))
    else:
        raise ValueError("Bit index must be between 0 and 80")

cdef inline void pop_bit(uint64_t* bb_segment, int index):
    """
    Pops bit of 64-bit int at given index
    """
    bb_segment[0] &= ~((<uint64_t>1) << index)

cdef inline uint16_t pop_lsb(uint64_t* bb_segment):
    """
    Finds and returns LSB square index, plus pops lsb in place. Used while iterating during move generation.
    """
    cdef int lsb_index
    lsb_index = lsb(bb_segment[0])
    pop_bit(bb_segment, lsb_index)

    return (<uint16_t>lsb_index)

cdef inline uint64_t merge(Bitboard board):
    """
    Uses OR to cast board uint64s together, returning a single uint64. Used to generate blocker keys.
    """
    return board.low | board.high

cdef int count_bits(uint64_t b):
    """
    Returns int count of set bits in a uint64 (Using Brian Kernighan's way).
    """
    cdef int r = 0
    while b:
        r += 1
        b &= b - 1
    return r

cdef int count_bits_board(Bitboard board):
    """
    Returns int count of set bits in a Bitboard.
    """
    return count_bits(board.low) + count_bits(board.high)

cdef inline uint64_t bit_toggle(uint64_t number, int n):
    """
    Toggles Bit to opposite of input uint64 at square index n. Returns new uint64.
    """
    return number ^ (1 << n)

cdef inline Bitboard and_board(Bitboard board_1, Bitboard board_2):
    cdef Bitboard board
    board.low = board_1.low & board_2.low
    board.high = board_1.high & board_2.high
    return board

## Need some Bitscan / LSB MSB finding functions
cdef int[64] DE_BRUIJN_INDEX = [
    0, 47,  1, 56, 48, 27,  2, 60,
   57, 49, 41, 37, 28, 16,  3, 61,
   54, 58, 35, 52, 50, 42, 21, 44,
   38, 32, 29, 23, 17, 11,  4, 62,
   46, 55, 26, 59, 40, 36, 15, 53,
   34, 51, 20, 43, 31, 22, 10, 45,
   25, 39, 14, 33, 19, 30,  9, 24,
   13, 18,  8, 12,  7,  6,  5, 63
]

cdef uint64_t DE_BRUIJN_64 = 0x03f79d71b4cb0a89

cdef inline int lsb(uint64_t x):
    """
    Returns index of least signficant bit for a given pointer to a uint_64. Must be non-zero.

    - Using Kim Walisch's extension of the De Bruijn method.
    """
    return DE_BRUIJN_INDEX[((x ^ (x-1)) * DE_BRUIJN_64) >> 58]

cdef inline int brian_kernighan_lsb(uint64_t x):
    """
    Less performant, but more robust lsb function. Keeping in code to validate De Bruijn lsb function.
    """
    return count_bits((x & -x)-1)

#==============================================================================
# Basic Bitboard Handling
#==============================================================================
#----------------------------------------------
# Setting, Clearing, Creating, Printing Boards
#----------------------------------------------
cdef void clear_all(Bitboard* board):
    """
    Clears all squares on the Bitboard.
    """
    board.low = ZERO
    board.high = ZERO

cdef void set_start_position(Bitboard* board):
    """
    Sets occupancy Bitboard values to Tablut starting position.
    """
    board.low = 0x04223FF888402038
    board.high = 0x0000000000007010

cdef Bitboard create_board(): #TODO: once I have other Bitboards, modify so this takes a function as an arg specifying which pos is initialised
    """
    Creates Bitboard from predefined positions.
    """
    cdef Bitboard bitboard
    set_start_position(&bitboard)
    return bitboard

cdef Bitboard create_random_board():
    cdef Bitboard board
    cdef uint64_t low_mask = 0x7FFFFFFFFFFFFFFF
    cdef uint64_t high_mask = 0x000000000003FFFF
    board.low = random_uint64_fewbits() & low_mask
    board.high = random_uint64_fewbits() & high_mask
    return board

cdef inline is_board_empty(Bitboard board):
    """
    Returns True if board has no bits set, else False
    """
    return board.low == ZERO and board.high == ZERO

cdef inline is_board_full(Bitboard board):
    """
    Returns True if board has all bits set, else False
    """
    return board.low == 0xFFFFFFFFFFFFFFFF and board.high == 0xFFFFFFFFFFFFFFFF

cdef inline same_board(Bitboard board_1, Bitboard board_2):
    """
    Returns True if two given boards have the same set bits, else False.
    """
    return board_1.low == board_2.low and board_1.high == board_2.high

def py_create_start_position():
    """
    Python accessible function to create a Bitboard in starting position.
    """
    return create_board()

def print_board(Bitboard board):
    """
    Python accessible function that prints a Bitboard.
    """
    cdef int rank, file, sq
    for rank in range(8, -1, -1):
        print(f"{rank+1} ", end="")
        for file in range(9):
            sq = rank * 9 + file
            print("1 " if is_bit_set(&board, sq) else ". ", end="")
        print()
    print("  a b c d e f g h i")
    print(f"Bitboard: low: {board.low} | high: {board.high}")
    print(f"Bitboard (hex): low: 0x{board.low:016X} | high: 0x{board.high:016X}\n")

def py_build_board(uint64_t low=ZERO, uint64_t high=ZERO, bint verbose=True):
    """
    Python accessible function that builds a board based on two uint64s.
    """
    cdef Bitboard board = Bitboard(low, high)
    if verbose:
        print_board(board)
    return board

#----------------------------------------------
# On the Fly ops
#----------------------------------------------
cdef Bitboard find_moves_otf(Bitboard board, int square):
    """
    Calculates moves on the fly for a given Bitboard and square. Returns Bitboard moves.
    """
    cdef Bitboard moves = Bitboard(ZERO,ZERO)
    cdef int j, rank, file

    rank = square // 9
    file = square % 9

    # move east
    for j in range(square + 1, (rank + 1) * 9):
        if is_bit_set(&board, j):
            break
        else:
            set_bit(&moves, j)

    # move west
    for j in range(square - 1, rank * 9 - 1, -1):
        if is_bit_set(&board, j):
            break
        else:
            set_bit(&moves, j)

    # move north
    for j in range(square + 9, 81, 9):
        if is_bit_set(&board, j):
            break
        else:
            set_bit(&moves, j)

    # move south
    for j in range(square - 9, -1, -9):
        if is_bit_set(&board, j):
            break
        else:
            set_bit(&moves, j)

    return moves

cdef Bitboard find_attacked_squares_otf(Bitboard attackers, int square): # TODO: uncomfortable with the naming overlap with the Tablut side name, but doesnt really matter
    cdef Bitboard attacked_squares = EMPTY_BITBOARD
    cdef int rank = square // 9

    if 0 <= square + 18 <= 80 and is_bit_set(&attackers, square + 18):
        set_bit(&attacked_squares, square + 9)
    if (0 <= square + 2 <= 80) and ((square + 2) // 9 == rank) and is_bit_set(&attackers, square + 2):
        set_bit(&attacked_squares, square + 1)
    if 0 <= square - 18 <= 80 and is_bit_set(&attackers, square - 18):
        set_bit(&attacked_squares, square - 9)
    if 0 <= square - 2 <= 80 and ((square - 2) // 9 == rank) and is_bit_set(&attackers, square - 2):
        set_bit(&attacked_squares, square - 1)

    return attacked_squares

#----------------------------------------------
# Leftover Logic for Generating Blocker Mask, Blocker Bits Constants
#----------------------------------------------

cdef Bitboard build_blocker_masks(Bitboard board, int square):
    """
    Builds a mask showing the full set of blocker squares for a given Bitboard and square. Returns Bitboard with all blockers.

    Use BLOCKER_MASK[square] instead, this was used primarily to build BLOCKER_MASK constants.
    """
    cdef Bitboard blockers = Bitboard(ZERO,ZERO)
    cdef int j, rank, file

    # rank moves
    if is_bit_set(&board, square):

      rank = square // 9
      file = square % 9

      # move east
      for j in range(square + 1, (rank + 1) * 9 - 1):
          if is_bit_set(&board, j):
              break
          else:
              set_bit(&blockers, j)

      # move west
      for j in range(square - 1, rank * 9, -1):
          if is_bit_set(&board, j):
              break
          else:
              set_bit(&blockers, j)

      # move north
      for j in range(square + 9, 72, 9):
          if is_bit_set(&board, j):
              break
          else:
              set_bit(&blockers, j)

      # move south
      for j in range(square - 9, 8, -9):
          if is_bit_set(&board, j):
              break
          else:
              set_bit(&blockers, j)
    else:
      print("no piece on square")

    return blockers

cdef void print_masks():
    """
    Used to print BLOCKER_MASK array.
    """
    cdef Bitboard bitboard
    cdef Bitboard blockers
    cdef int i

    for i in range(81):
      clear_all(&bitboard)
      set_bit(&bitboard, i)
      blockers = build_blocker_masks(bitboard, i)
      print(f"Bitboard(low = 0x{blockers.low:016X}, high = 0x{blockers.high:016X}),")

cdef void print_relevant_bits(str mask):
    """
    Used to print BLOCKER_BITS / ATTACK_BITS array. Use keyword 'blocker' or 'attack'
    """
    cdef int i
    cdef Bitboard board = EMPTY_BITBOARD
    cdef int count

    for i in range(81):
        set_bit(&board, i)
        if mask == 'blocker':
            count = count_bits_board(BLOCKER_MASK[i])
        elif mask == 'attack':
            count = count_bits_board(ATTACK_MASKS[i])
        else:
            print('INVALID ARG print_relevant_bits. Use "attack" or "blocker"')
            return
        clear_bit(&board, i)
        print(f'{count}, ', end='')
        if (i + 1) % 9 == 0:
            print()

#----------------------------------------------
# Attack Masks
#----------------------------------------------
cdef Bitboard build_attack_masks(int square):
    cdef Bitboard attack_mask = EMPTY_BITBOARD
    cdef int rank = square // 9

    if 0 <= square + 18 <= 80:
        set_bit(&attack_mask, square + 18)
    if (0 <= square + 2 <= 80) and ((square + 2) // 9 == rank):
        set_bit(&attack_mask, square + 2)
    if 0 <= square - 18 <= 80:
        set_bit(&attack_mask, square - 18)
    if 0 <= square - 2 <= 80 and ((square - 2) // 9 == rank):
        set_bit(&attack_mask, square - 2)

    return attack_mask

def print_attack_masks():
    print("cdef Bitboard[81] ATTACK_MASKS = [")
    for i in range(81):
      attack_mask = build_attack_masks(i)
      print(f"Bitboard(low = 0x{attack_mask.low:016X}, high = 0x{attack_mask.high:016X}),")
    print("]")

#==============================================================================
# Finding Magic Numbers
#==============================================================================

cdef inline get_hash_value(uint64_t blocker_key, uint64_t magic, int shift_bits):
    """
    Applies the magic multiplation and right shift, returns a 64-bit ULL index.
    """
    return (blocker_key * magic) >> shift_bits

cdef uint64_t random_u64():
    """
    Returns a random 64-bit ULL.

    - uses Python's random module, which returns 32 bit int. We call this twice, shifting the first random int over 32 bits for a total of 64
    - potential to improve robustness of random generation, but seems fine for purpose for now.
    """
    cdef uint64_t r = 0
    r = (random.randint(0, 0xFFFFFFFF) << 32) | random.randint(0, 0xFFFFFFFF)
    return r

cdef uint64_t random_uint64_fewbits():
    """
    Returns a sparse random 64-bit ULL.

    - we only want a few bits set, so 3 AND operations are performed on random uint64s. These 'sparse' magics are shown to be more successful.
    """
    return random_u64() & random_u64() & random_u64()

cdef Bitboard carry_rippler_next(Bitboard subset, Bitboard mask):
    """
    Carry Rippler trick for finding subsets of a set. Returns next subset (Bitboard).
    """
    cdef Bitboard next
    cdef uint64_t carry

    next.low = (subset.low - mask.low) & mask.low
    carry = (subset.low - mask.low) > subset.low  # important for transversing board uint64s
    next.high = ((subset.high - carry) - mask.high) & mask.high

    return next

#----------------------------------------------------
# Build matching uint64 key and Bitboard value table
#----------------------------------------------------
cdef struct KeyBoardTable:
    uint64_t* key
    Bitboard* board
    size_t size

cdef KeyBoardTable build_key_board_table(int square, Bitboard mask, int bits, bb_func otf_func):
    """
    Building the Attacked Square Tables. Returns constructed tables.

    - for a square, gets relevant attacking allies mask
    - instantiates tables and allocates memory
    - uses Carry Rippler trick to calculate all possible subsets
    - for each subset, calculates the corresponding attacked square
    - sets table size as 2^blocker squares
    """

    cdef KeyBoardTable table
    cdef Bitboard subset = EMPTY_BITBOARD
    cdef int index = 0

    table.size = 1 << bits
    table.key = <uint64_t*>malloc(table.size * sizeof(uint64_t))
    table.board = <Bitboard*>malloc(table.size * sizeof(Bitboard))

    if table.key == NULL or table.board == NULL:
        free_key_board_table(&table)
        raise MemoryError("Failed to allocate memory for key/board table")

    while True:
        table.key[index] = merge(subset)
        table.board[index] = otf_func(subset, square)
        index += 1
        subset = carry_rippler_next(subset, mask)
        if subset.low == 0 and subset.high == 0:
            break

    return table

cdef void free_key_board_table(KeyBoardTable* table):
    """
    Sets KeyBoard table to NULL and frees allocated memory.
    """
    if table.key != NULL:
        free(table.key)
        table.key = NULL
    if table.board != NULL:
        free(table.board)
        table.board = NULL
    table.size = 0

#--------------------------------------------------
# Searching for Magics - Brute Force Trial & Error
#--------------------------------------------------
cdef uint64_t find_magic(int square, Bitboard mask, int bits, int shift_bits, bb_func otf_func):
    """
    Finds a magic number for a given square (0-80). Returns magic if succesful, else prints warning and returns an empty 64-bit ULL.

    """
    cdef uint64_t merged_mask = merge(mask) # think this is just equal to table.size??
    cdef KeyBoardTable table = build_key_board_table(square, mask, bits, otf_func)
    cdef size_t used_size = 1 << (64 - shift_bits) # annoyingly, this is not always equal to blocker_bits thanks to 17 and 53
    cdef Bitboard* used = <Bitboard*>malloc(used_size * sizeof(Bitboard))
    cdef uint64_t k, i, index, fail, counter, max_counter = 0
    cdef uint64_t magic, best_magic = 0
    cdef uint64_t FAILED_MAGIC = ZERO
    cdef uint64_t MAX_ITERATIONS = 100000000

    if used == NULL:
        free_key_board_table(&table)
        raise MemoryError("Failed to allocate memory for used array")

    try:
        with tqdm(total=MAX_ITERATIONS, desc=f"Finding Magic for Square {square}", unit="magic") as pbar:
            for k in range(MAX_ITERATIONS):
                magic = random_uint64_fewbits()
                if count_bits((merged_mask * magic) & 0xFFF0000000000000) < 6:  # Changed this from Chess Wiki to match Apery's magic filter - significant speedup as a result
                    pbar.update(1)
                    continue

                # Reset the used array
                for i in range(used_size):
                    used[i] = FULL_BITBOARD

                fail, counter = 0, 0
                while fail == 0 and counter < table.size:
                    index = get_hash_value(table.key[counter], magic, shift_bits)
                    if is_board_full(used[index]):
                        used[index] = table.board[counter]
                    elif not same_board(used[index], table.board[counter]):
                        fail = 1
                    counter += 1

                if counter > max_counter:
                    max_counter = counter
                    best_magic = magic

                if fail == 0:
                    return magic

                pbar.update(1)
                if k % 100000 == 0:  # Update description
                    pbar.set_description(f"Square {square}: Best {max_counter}/{table.size}")

        print(f"***Failed to find Magic for square {square}. Best Magic {best_magic:016X} passed first {max_counter} entries ({max_counter/table.size:.2%})***")
        return FAILED_MAGIC
    finally:
        free(used)
        free_key_board_table(&table)

def find_magics(squares=None, action="moves"):
    """
    Python-accessible function to find, print and return magic numbers for specified/all board squares.

    - param squares: List or array of square indices to find magics for. If None, finds magics for all squares.
    - 'action' paramater to specify which magics are being searched for from ["moves", "attacks"]. Defaults to "moves".
    - return: Dictionary mapping square indices to their magic numbers.
    """
    cdef array.array square_array
    cdef int square, i
    cdef uint64_t magic
    cdef dict magic_dict = {}
    cdef bb_func otf_func
    if action == "moves":
        otf_func = find_moves_otf
    elif action == "attacks":
        otf_func = find_attacked_squares_otf
    else:
        print("action not recognised")
        return

    if squares is None:
        squares = range(81)

    square_array = array.array('i', squares)

    if min(square_array) < 0 or max(square_array) > 80:
        raise ValueError("Invalid square(s). Must be: 0 <= square <= 80")

    for i in range(len(square_array)):
        square = square_array[i]
        mask = BLOCKER_MASK[square] if action == "moves" else ATTACK_MASKS[square]
        bits = BLOCKER_BITS[square] if action == "moves" else ATTACK_BITS[square]
        shift_bits = SHIFT_BITS[square] if action == "moves" else ATTACK_SHIFT_BITS[square]
        magic = find_magic(square, mask, bits, shift_bits, otf_func)
        if magic != 0:
            magic_dict[square] = magic
        else:
            magic_dict[square] = '***FAILED***'

    print("MAGICS\n-------------------------------------")
    for square in square_array:
        print(f"Square {square} Magic: 0x{magic_dict.get(square, 0):016X}")

    return magic_dict

#----------------------------------------------
# Simulated Annealing for Magic Search - FOR POSTERITY
#----------------------------------------------
cdef int collision_count(uint64_t magic, KeyBoardTable* table, Bitboard* used, int n_bits):
    """
    Returns number of collisions generated by trying to hash blocker - move pairs for a square. Used as cost function for simulated annealing.
    """
    cdef int collisions, counter

    # Reset the used array
    for i in range(table.size):
        used[i] = FULL_BITBOARD

    collisions, counter = 0, 0
    while counter < table.size:
        index = get_hash_value(table.key[counter], magic, n_bits)
        if is_board_full(used[index]): #TODO: I believe there is a flaw in this logic due to empty move sets that may have already been mapped
            used[index] = table.board[counter]
        elif not same_board(used[index], table.board[counter]):
            collisions += 1
        counter += 1

    return collisions

cdef uint64_t neighboring_magic(uint64_t magic):
    """
    Idea here was to toggle a random bit in the magic candidate to produce a neighbour. Quite a naive approach. Had some decent results in finding most performant magics for the 'impossible' squares (17, 53).
    """
    cdef int index = random.randint(0, 63)
    return bit_toggle(magic, index)

cdef float acceptance_probability(int old_cost, int new_cost, float T):
    """
    Calculating acceptance probability for simulated annealing.
    """
    if new_cost < old_cost:
        return 1.0
    return exp((old_cost - new_cost) / T)

cdef simulated_annealing_magic(int square, uint64_t magic):
    """
    Logic for attempting to find a magic candidate for given square via simulated annealing.
    """
    cdef int n_bits = BLOCKER_BITS[square]
    cdef KeyBoardTable tables  = build_key_board_table(square, BLOCKER_MASK[square], BLOCKER_BITS[square], find_moves_otf)
    cdef Bitboard* used = <Bitboard*>malloc(tables.size * sizeof(Bitboard))
    if used == NULL:
        raise MemoryError("Failed to allocate memory for used array")

    cdef float T = 1.0
    cdef float alpha = 0.99  # Cooling rate
    cdef uint64_t best_magic = magic
    cdef int old_cost = collision_count(magic, &tables, used, n_bits)
    if old_cost == 0:
        return magic

    cdef int best_cost = old_cost
    if best_cost < 28:
        print(f"New Benchmark: Magic {best_magic:016X} with {best_cost} collisions.")
    cdef uint64_t new_magic
    cdef int new_cost
    cdef float ap

    try:
        while T > 0.001:
            for i in range(10000):  # Number of iterations per temperature
                new_magic = neighboring_magic(magic)
                new_cost = collision_count(new_magic, &tables, used, n_bits)
                if new_cost == 0:
                    return new_magic
                if new_cost < best_cost:
                    best_cost = new_cost
                    best_magic = new_magic
                    if new_cost < 28:
                        print(f"New Benchmark: Magic {best_magic:016X} with {best_cost} collisions.")
                ap = acceptance_probability(old_cost, new_cost, T)
                if ap > random.random():
                    magic = new_magic
                    old_cost = new_cost
            T *= alpha
    finally:
        free(&used)
        free_key_board_table(&tables)
    print(f"best was {best_cost} collisions")
    return ZERO

def simulated_annealing(int square, uint64_t user_magic=ZERO):
    """
    Python-accessible function to find a magic for a given square. If no starting magic is provided, a random one is generated. Returns successful magic in hex format if found.
    """
    cdef uint64_t mask = merge(get_blocker_mask(square))
    cdef uint64_t magic
    cdef uint64_t starting_magic

    print(f"Searching for a Square {square} Magic...")
    for i in range(10):  # very ineffecient to loop here - remaking the tables each time.
        if user_magic == ZERO:
            starting_magic = random_uint64_fewbits()
            while True:
                if count_bits((mask * starting_magic) & 0xFFF0000000000000) >= 6:
                    break
                starting_magic = random_uint64_fewbits()
        else:
            starting_magic = user_magic
        magic = simulated_annealing_magic(square, starting_magic)
        if magic != ZERO:
            print(f"Sqaure {square} Magic Found!!!\n{magic:016X}")
            return
    print("No Magic Found :(")

#==============================================================================
# Move Tables
#==============================================================================

cdef struct MoveTable:
    Bitboard* moves
    int size

cdef class MoveTables:
    cdef MoveTable[81] tables

    def __cinit__(self):
        cdef int i
        for i in range(81):
            self.tables[i].moves = NULL
            self.tables[i].size = 0

        self.build_move_tables()

    def __dealloc__(self):
        cdef int i
        for i in range(81):
            if self.tables[i].moves != NULL:
                free(self.tables[i].moves)

    cdef void set_table(self, int square, KeyBoardTable* blocker_moves, int size):
        if self.tables[square].moves != NULL:
            free(self.tables[square].moves)

        self.tables[square].moves = <Bitboard*>malloc(size * sizeof(Bitboard))
        if self.tables[square].moves == NULL:
            raise MemoryError("Failed to allocate memory for used array (Move Tables)")
        self.tables[square].size = size

        cdef int i
        for i in range(blocker_moves.size):
            index = get_hash_value(blocker_moves.key[i], MAGIC[square], SHIFT_BITS[square])
            self.tables[square].moves[index] = blocker_moves.board[i]

    cdef Bitboard get_move(self, int square, Bitboard occupancy):
        cdef uint64_t blocker_key = merge(get_blockers(occupancy, square))
        cdef int index = get_hash_value(blocker_key, MAGIC[square], SHIFT_BITS[square])
        return self.tables[square].moves[index]

    def py_get_move(self, int square, Bitboard occupancy):
        return self.get_move(square, occupancy)

    cdef void build_move_tables(self):
        cdef KeyBoardTable blocker_moves
        cdef int i, size
        for i in tqdm(range(81), desc="Building Move Tables..."):
            blocker_moves = build_key_board_table(i, BLOCKER_MASK[i], BLOCKER_BITS[i], find_moves_otf)
            size = 1 << (64 - SHIFT_BITS[i])
            self.set_table(i, &blocker_moves, size)
            free_key_board_table(&blocker_moves)

        print('Move Tables Initialised.')

#==============================================================================
# Attack Tables - Pretty Much Duplicated from Above
#==============================================================================

cdef struct AttackTable:
    Bitboard* attacks
    int size

cdef class AttackTables:
    cdef AttackTable[81] tables

    def __cinit__(self):
        cdef int i
        for i in range(81):
            self.tables[i].attacks = NULL
            self.tables[i].size = 0

        self.build_attack_tables()

    def __dealloc__(self):
        cdef int i
        for i in range(81):
            if self.tables[i].attacks != NULL:
                free(self.tables[i].attacks)

    cdef void set_table(self, int square, KeyBoardTable* allies_attacks, int size):
        if self.tables[square].attacks != NULL:
            free(self.tables[square].attacks)

        self.tables[square].attacks = <Bitboard*>malloc(size * sizeof(Bitboard))
        if self.tables[square].attacks == NULL:
            raise MemoryError("Failed to allocate memory for used array (Attack Tables)")
        self.tables[square].size = size

        cdef int i
        for i in range(allies_attacks.size):
            index = get_hash_value(allies_attacks.key[i], ATTACK_MAGICS[square], ATTACK_SHIFT_BITS[square])
            self.tables[square].attacks[index] = allies_attacks.board[i]

    cdef Bitboard get_attacks(self, int square, Bitboard allies):
        cdef uint64_t ally_key = merge(get_attack_allies(allies, square))
        cdef int index = get_hash_value(ally_key, ATTACK_MAGICS[square], ATTACK_SHIFT_BITS[square])
        return self.tables[square].attacks[index]

    def py_get_attacks(self, int square, Bitboard allies):
        return self.get_attacks(square, allies)

    cdef void build_attack_tables(self):
        cdef KeyBoardTable allies_attacks
        cdef int i, size
        for i in tqdm(range(81), desc="Building Attack Tables..."):
            allies_attacks = build_key_board_table(i, ATTACK_MASKS[i], ATTACK_BITS[i], find_attacked_squares_otf)
            size = 1 << (64 - ATTACK_SHIFT_BITS[i])
            self.set_table(i, &allies_attacks, size)
            free_key_board_table(&allies_attacks)

        print('Attack Tables Initialised.')

def py_build_attack_tables():
    cdef AttackTables attack_tables = AttackTables()
    return attack_tables

#==============================================================================
# Game Instance - As an Object for now
#==============================================================================

cdef class GameState:
    #cdef MoveTables move_tables = build_move_tables()
    cdef Bitboard occupancy
    cdef Bitboard attackers
    cdef Bitboard defenders
    cdef Bitboard king
    cdef Bitboard all_defenders
    cdef Bitboard throne

    cdef int side

    def __cinit__(self):
        self.set_start_pos()

    def set_start_pos(self):
        self.occupancy = Bitboard(0x04223FF888402038, 0x0000000000007010)
        self.attackers = Bitboard(0x0020383808002038, 0x0000000000007010)
        self.defenders = Bitboard(0x040206C080400000,0x0000000000000000)
        self.king = Bitboard(0x0000010000000000,0x0000000000000000)
        self.all_defenders = Bitboard(0x040207C080400000,0x0000000000000000)
        self.throne = Bitboard(0x0000010000000000,0x0000000000000000)
        self.side = 1

    def change_turn(self):
        self.side = self.side * -1

    def print_bitboards(self):
        print("CURRENT POSITION\n---------- OCCUPANCY ----------")
        print_board(self.occupancy)
        print("---------- ATTACKERS ----------")
        print_board(self.attackers)
        print("---------- DEFENDERS ----------")
        print_board(self.defenders)
        print("------------ KING ------------")
        print_board(self.king)
        print("-------- ALL DEFENDERS --------")
        print_board(self.all_defenders)
        print("----------- THRONE -----------")
        print_board(self.throne)

    def print_board(self, unicode=True):
        is_mac = sys.platform == 'darwin'
        if not unicode == True:
            is_mac = False

        EMPTY = '·'
        KING = '♔' if is_mac else 'K'
        DEFENDER = '♙' if is_mac else 'D'
        ATTACKER = '♟' if is_mac else 'A'
        THRONE = '☆' if is_mac else 'T'

        board = [[EMPTY for _ in range(9)] for _ in range(9)]

        board[4][4] = THRONE

        def set_piece(bitboard, symbol):
            for i in range(9):
                for j in range(9):
                    if is_bit_set_2(bitboard, i * 9 + j):
                        board[i][j] = symbol

        set_piece(self.king, KING)
        set_piece(self.defenders, DEFENDER)
        set_piece(self.attackers, ATTACKER)

        print("   a b c d e f g h i  ")
        for i, row in enumerate(board):
            print(f"{9-i:2d}", end=' ')
            for cell in row:
                print(cell, end=' ')
            print(f"{9-i:2d}")
        print("   a b c d e f g h i  ")

#==============================================================================
# Move Generation
#==============================================================================

cdef struct MoveList:
    uint16_t* moves
    int size
    int count

cdef MoveList* build_move_list() except NULL:
    cdef MoveList* list = <MoveList*>malloc(sizeof(MoveList))
    if list == NULL:
        raise MemoryError("Failed to allocate memory for MoveList struct")

    list.size = 256
    list.count = 0
    list.moves = <uint16_t*>malloc(list.size * sizeof(uint16_t))

    if list.moves == NULL:
        free(list)
        raise MemoryError("Failed to allocate memory for moves array")

    return list

cdef void free_move_list(MoveList* list):
    if list != NULL:
        if list.moves != NULL:
            free(list.moves)
        free(list)

cdef inline Bitboard filter_king_moves(Bitboard* empty, Bitboard* raw_moves):
    cdef Bitboard moves
    moves.low = raw_moves.low & empty.low
    moves.high = raw_moves.high & empty.high
    return moves

cdef inline Bitboard filter_piece_moves(Bitboard* occupancy, Bitboard* raw_moves):
    cdef Bitboard moves
    moves.low = raw_moves.low & ~occupancy.low & THRONE_MASK
    moves.high = raw_moves.high & ~occupancy.high
    return moves

cdef inline uint16_t encode_move(uint16_t from_square_shifted, uint16_t to_square, bint is_king):
    cdef uint16_t encoded_move
    encoded_move = from_square_shifted | to_square
    if is_king == True:
        encoded_move = encoded_move | KING_MOVE_FLAG
    return encoded_move

cdef void find_moves(MoveList* move_list, MoveTables* move_table, GameState* position):
    """
    Takes pointers to MoveList, MoveTables, and GameState, modifying MoveList in place with all legal moves. Resets move list at the start.
    """
    cdef Bitboard move_board
    move_list.count = 0

    if position.side == 1:
        move_board = position.all_defenders
    else:
        move_board = position.attackers

    while move_board.low != ZERO or move_board.high != ZERO:
        if move_board.low != ZERO:
            from_square = pop_lsb(&move_board.low)
        else:
            from_square = pop_lsb(&move_board.high) + 63
        legal_moves = move_table.get_move(from_square, position.occupancy)
        legal_moves = filter_piece_moves(&position.occupancy, &legal_moves)

        while legal_moves.low != ZERO or legal_moves.high != ZERO:
            if legal_moves.low != ZERO:
                to_square = pop_lsb(&legal_moves.low)
            else:
                to_square = pop_lsb(&legal_moves.high) + 63

            encoded_move = (from_square << 7) | to_square

            move_list.moves[move_list.count] = encoded_move
            move_list.count += 1

#==============================================================================
# Tablut Engine Class - prepares gamespace
#==============================================================================

cdef void initialize_tables():
    global global_move_tables, global_attack_tables
    if global_move_tables is NULL:
        global_move_tables = MoveTables()
    if global_attack_tables is NULL:
        global_attack_tables = AttackTables()

cdef void cleanup_tables():
    global global_move_tables, global_attack_tables
    if global_move_tables is not NULL:
        del global_move_tables
        global_move_tables = NULL
    if global_attack_tables is not NULL:
        del global_attack_tables
        global_attack_tables = NULL

cdef class TablutEngine:
    def __cinit__(self):
        initialize_tables()

    def __dealloc__(self):
        cleanup_tables()

    def some_method(self):
        some_function_using_tables()

#==============================================================================
# Python Acessible Tests
#==============================================================================

def print_blocker_masks():
    """
    Python-friendly function to print BLOCKER_MASK values
    """
    print_masks()

def print_mask_bitcount(str mask):
    """
    Python-friendly function to print BLOCKER_BITS/ATTACK_BITS count for board
    """
    print_relevant_bits(mask)

def py_start_pos():
    cdef Bitboard b = Bitboard(0,0)

    set_bit(&b, 40)

    print_board(b)

def py_demonstrate_blocker_merge(int square):
    cdef Bitboard unmerged = get_blocker_mask(square)
    cdef uint64_t merged = merge(unmerged)
    print(f"Unmerged Blockers at Square {square}:")
    print_board(unmerged)
    print("---------------------")
    print("Merged Board (disregard top two rows):")
    print_board(Bitboard(merged, 0))

def test():
    cdef uint64_t r = random_u64()
    cdef Bitboard board = Bitboard(r, 0)
    print(r)
    print_board(board)

def py_build_bm_tables(int square):
    """
    Python-friendly test to inspect the BlockerMoveTables. Returns BlockerMoveTable for given square.
    """
    cdef KeyBoardTable tables = build_key_board_table(square, BLOCKER_MASK[square], BLOCKER_BITS[square], find_moves_otf)
    blockers = [tables.key[i] for i in range(tables.size)]
    moves = [tables.board[i] for i in range(tables.size)]
    free_key_board_table(&tables)

    return blockers, moves

def test_magic(int square, uint64_t magic, str magic_type="moves", verbose=False):
    cdef KeyBoardTable tables
    if magic_type == "moves":
        tables = build_key_board_table(square, BLOCKER_MASK[square], BLOCKER_BITS[square], find_moves_otf)
    elif magic_type == "attacks":
        tables = build_key_board_table(square, ATTACK_MASKS[square], ATTACK_BITS[square], find_attacked_squares_otf)
    else:
        print("Please re-check magic_type")
    cdef int shift_bits = SHIFT_BITS[square] if magic_type == "moves" else ATTACK_SHIFT_BITS[square]
    cdef size_t used_size = 1 << (64 - shift_bits)

    cdef Bitboard* used = <Bitboard*>malloc(used_size * sizeof(Bitboard))
    if used == NULL:
        raise MemoryError("Failed to allocate memory for used array")

    for i in range(used_size):
        used[i] = FULL_BITBOARD

    unique, constructive, destructive = 0, 0, 0
    for i in range(tables.size):
        index = get_hash_value(tables.key[i], magic, shift_bits)
        if is_board_full(used[index]):
            used[index] = tables.board[i]
            if verbose:
                print(f'{magic_type[:-1]} {i} successfully hashed to index {index}')
            unique += 1
        else:
            if same_board(used[index], tables.board[i]):
                if verbose:
                    print(f"constructive collision for {magic_type[:-1]} {i} at index {index}")
                constructive += 1
            else:
                if verbose:
                    print(f"!!!COLLISION FOR {str.capitalize(magic_type[:-1])} {i} AT INDEX {index}")
                destructive += 1

    print(f"SQUARE {square}: unique: {unique} | constructive: {constructive} | destructive: {destructive}")
    free(&used)
    free_key_board_table(&tables)

def py_build_attacked_square_tables(int square):
    """
    Python-friendly test to inspect the AttackedSquareTables. Returns AttackedSquareTables for given square.
    """
    cdef bb_func otf_func = find_attacked_squares_otf
    cdef KeyBoardTable tables = build_key_board_table(square, ATTACK_MASKS[square], ATTACK_BITS[square], otf_func)
    keys = [tables.key[i] for i in range(tables.size)]
    boards = [tables.board[i] for i in range(tables.size)]
    free_key_board_table(&tables)

    return keys, boards

cdef int find_lsb(Bitboard bb):
    if bb.low != ZERO:
        return lsb(bb.low)
    elif bb.high != ZERO:
        return lsb(bb.high) + 63
    else:
        return -1

cdef void print_binary(uint64_t n):
    cdef int i
    for i in range(63, -1, -1):
        printf("%d", (n >> i) & 1)
    printf("\n")

cdef void test_lsb_methods():
    """
    Test results show that lsb function works great - except returns 63 when shown an empty BB
    """
    cdef uint64_t[21] test_values = [
        1, 2, 4, 8, 16, 32, 64, 128,
        3, 5, 7, 9, 15, 17, 31, 33,
        0xFFFFFFFFFFFFFFFF,
        0x8000000000000000,
        0x0000000000000001,
        0x0000000100000000,
        0x0000000000000000
    ]
    cdef int num_tests = 21
    cdef int i, de_bruijn_result, kernighan_result

    for i in range(num_tests):
        de_bruijn_result = lsb(test_values[i])
        kernighan_result = brian_kernighan_lsb(test_values[i])

        printf("Test value: %llu\n", test_values[i])
        printf("De Bruijn result: %d\n", de_bruijn_result)
        printf("Kernighan result: %d\n", kernighan_result)

        if de_bruijn_result != kernighan_result:
            printf("Mismatch found!\n")

        printf("\n")

def py_test_lsb_methods():
    test_lsb_methods()

cdef void test_random_bitboard_lsb():
  cdef int i, test_lsb, true_lsb
  cdef Bitboard board
  cdef uint64_t mask

  for i in range(1000):  # Test 1000 random boards
      board = create_random_board()
      test_lsb = find_lsb(board)

      # Find true LSB for verification
      if board.low != ZERO:
          true_lsb = brian_kernighan_lsb(board.low)
      elif board.high != ZERO:
          true_lsb = brian_kernighan_lsb(board.high) + 63
      else:
        true_lsb = -1

      if test_lsb != true_lsb:
          printf("Mismatch found:\n")
          printf("Low:  ")
          print_binary(board.low)
          printf("High: ")
          print_binary(board.high)
          printf("Found LSB: %d, True LSB: %d\n", test_lsb, true_lsb)
          return

  printf("All 1000 random bitboard tests passed successfully.\n")

def py_test_random_bitboard_lsb():
    test_random_bitboard_lsb()

cdef class Timer:
    cdef double start_time

    cpdef void start(self):
        self.start_time = clock()

    cpdef double end(self):
        cdef double end_time = clock()
        return (end_time - self.start_time) / CLOCKS_PER_SEC

cdef void test_itererate_pop_lsb():
    cdef Bitboard bb = EMPTY_BITBOARD
    cdef int i
    cdef uint16_t index

    print_board(bb)
    print("-------------------")
    for i in range(81):
        set_bit(&bb, i)

    print_board(bb)
    print("-------------------")
    while bb.low != ZERO:
        index = pop_lsb(&bb.low)
        print_board(bb)
        print(index)
        print("-------------------")
    while bb.high != ZERO:
        index = pop_lsb(&bb.high) + 63
        print_board(bb)
        print(index)
        print("-------------------")

def py_test_pop_lsb():
    test_itererate_pop_lsb()

cdef void print_move(uint16_t encoded_move):
    cdef int from_square = encoded_move >> 7
    cdef int to_square = encoded_move & 127

    cdef char from_file = (from_square % 9) + 97  # 97 is ASCII for 'a'
    cdef int from_rank = 9 - (from_square // 9)
    cdef char to_file = (to_square % 9) + 97
    cdef int to_rank = 9 - (to_square // 9)

    printf("%c%d-%c%d\n", from_file, from_rank, to_file, to_rank)

cdef main():
    cdef MoveTables Moves = MoveTables()
    cdef AttackTables Attacks = AttackTables()
    cdef MoveList move_list = build_move_list()
    cdef GameState Position = GameState()
    cdef int i = 0 # move_list counter
    cdef int from_square, to_square
    cdef uint16_t encoded_move

    try:
        Position.print_board()
        #Position.change_turn()
        find_moves(&move_list, &Moves, &Position)

        printf("Generated %d moves:\n", move_list.count)
        for i in range(move_list.count):
            printf("Move %d: ", i+1)
            print_move(move_list.moves[i])

        printf("Total number of moves: %d\n", move_list.count)
    finally:
        free_move_list(&move_list)

def py_main():
    main()

# TODO: find_moves is now broken, MoveTables, AttackTables, GameState can't be passed as pointers. This is actually ok for MoveTables and AttackTables as these are instantiatd once when module is loaded / program is started. Gamestate should be a struct. Others should be created at runtime?
