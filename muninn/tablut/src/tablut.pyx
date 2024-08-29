# cython: language_level=3

#------------------------------------------------------------------------------
# Imports and Type Declarations
#------------------------------------------------------------------------------

from libc.stdint cimport uint64_t
from cpython.dict cimport PyDict_SetItem, PyDict_GetItem
from cpython.object cimport PyObject
from tqdm import tqdm
from libc.stdlib cimport malloc, free
from libc.stdlib cimport rand
from libc.stddef cimport size_t

# TO UPDATE CYTHON CODE USE BELOW
# python setup.py build_ext --inplace

#------------------------------------------------------------------------------
# Bitboard Struct and Mask Constants
#------------------------------------------------------------------------------
cdef struct Bitboard:
    uint64_t low
    uint64_t high

cdef Bitboard[81] BLOCKER_MASK = [
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

# Fast, inline access function
cdef inline Bitboard get_blocker_mask(int index):
    return Bitboard(BLOCKER_MASK[index].low, BLOCKER_MASK[index].high)

cdef int[81] BLOCKER_BITS = [
    14, 13, 13, 13, 13, 13, 13, 13, 14,
    13, 12, 12, 12, 12, 12, 12, 12, 13,
    13, 12, 12, 12, 12, 12, 12, 12, 13,
    13, 12, 12, 12, 12, 12, 12, 12, 13,
    13, 12, 12, 12, 12, 12, 12, 12, 13,
    13, 12, 12, 12, 12, 12, 12, 12, 13,
    13, 12, 12, 12, 12, 12, 12, 12, 13,
    13, 12, 12, 12, 12, 12, 12, 12, 13,
    14, 13, 13, 13, 13, 13, 13, 13, 14]

#------------------------------------------------------------------------------
# Bit Manipulation Macros
#------------------------------------------------------------------------------
cdef void set_bit(Bitboard* board, int index):
    if 0 <= index < 63:
        board.low |= (<uint64_t>1) << index
    elif 63 <= index < 81:
        board.high |= (<uint64_t>1) << (index - 63)
    else:
        raise ValueError("Bit index must be between 0 and 80")

cdef bint is_bit_set(Bitboard* board, int index):
    if 0 <= index < 63:
        return bool(board.low & ((<uint64_t>1) << index))
    elif 63 <= index < 81:
        return bool(board.high & ((<uint64_t>1) << (index - 63)))
    else:
        raise ValueError("Bit index must be between 0 and 80")

cdef void clear_bit(Bitboard* board, int index):
    if 0 <= index < 63:
        board.low &= ~((<uint64_t>1) << index)
    elif 63 <= index < 81:
        board.high &= ~((<uint64_t>1) << (index - 63))
    else:
        raise ValueError("Bit index must be between 0 and 80")

cdef inline uint64_t merge(Bitboard board):
    return board.low | board.high

cdef int count_bits(uint64_t b):
    cdef int r = 0
    while b:
        r += 1
        b &= b - 1
    return r

cdef int count_bits_board(Bitboard board):
    return count_bits(board.low) + count_bits(board.high)

#------------------------------------------------------------------------------
# Setting, Clearing, Printing Boards
#------------------------------------------------------------------------------
cdef void clear_all(Bitboard* board):
    board.low = 0
    board.high = 0

cdef void set_start_position(Bitboard* board):
    board.low = 0x04223FF888402038
    board.high = 0x0000000000007010

cdef Bitboard create_board():
    cdef Bitboard bitboard
    set_start_position(&bitboard)
    return bitboard

def create_start_position():
    return create_board()

def print_board(Bitboard board):
    cdef int rank, file, sq
    for rank in range(8, -1, -1):
        print(f"{rank+1} ", end="")
        for file in range(9):
            sq = rank * 9 + file
            print("1 " if is_bit_set(&board, sq) else ". ", end="")
        print()
    print("  a b c d e f g h i")
    print(f"Bitboard: {board.low} {board.high}")
    print(f"Bitboard (hex): 0x{board.low:016X} 0x{board.high:016X}\n")

#------------------------------------------------------------------------------
# Move Key Generation
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Magic Number Generation
#------------------------------------------------------------------------------
# find possible moves for a given square and boardstate on the fly
cdef Bitboard find_moves_otf(Bitboard board, int square):
    cdef Bitboard moves = Bitboard(0,0)
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

#------------------------------------------------------------------------------
# Generating Blocker Masks
#------------------------------------------------------------------------------
cdef Bitboard build_blocker_masks(Bitboard board, int square):
    cdef Bitboard blockers = Bitboard(0,0)
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
    cdef Bitboard bitboard
    cdef Bitboard blockers
    cdef int i

    for i in range(81):
      clear_all(&bitboard)
      set_bit(&bitboard, i)
      blockers = build_blocker_masks(bitboard, i)
      print(f"Bitboard(low = 0x{blockers.low:016X}, high = 0x{blockers.high:016X}),")
"""
cdef void iterate_subsets(Bitboard mask):
    cdef uint64_t subset = 0
    cdef uint64_t temp
    cdef int counter = 0
    cdef uint64_t merged_mask = merge(mask)
    cdef Bitboard tmp = Bitboard(0,0)

    while True:
        counter += 1
        print(counter)
        # Use subset here
        tmp.low = subset
        print_board(tmp)

        # Generate next subset
        temp = (subset - merged_mask) & merged_mask
        subset = temp

        if subset == 0:
            break
"""

cdef void print_relevant_bits():
    cdef int i
    cdef Bitboard board = Bitboard(0,0)
    cdef int count

    for i in range(81):
        set_bit(&board, i)
        count = count_bits_board(build_blocker_masks(board, i))
        clear_bit(&board, i)
        print(f'{count}, ', end='')
        if (i + 1) % 9 == 0:
            print()

#==============================================================================
# Finding Magic Numbers
#==============================================================================
#----------------------------------------
# Random uint64 Generation
#----------------------------------------
cdef uint64_t random_u64():
    cdef uint64_t r = 0
    for _ in range(5):  # We only need 5 iterations to fill 64 bits
        r = (r << 15) | (rand() & 0x7FFF)
    return r

#----------------------------------------
# Magic Transformation
#----------------------------------------
cdef int transform(uint64_t key, uint64_t magic, int bits):
    return (key * magic) >> (64 - bits)

#-------------------------------------------------
# Build matching blocker subset and attack tables
#-------------------------------------------------
"""
cdef struct BlockerAttackTables():
    uint64_t* blocker
    uint64_t* attack

cdef BlockerAttackTables build_blocker_attack_tables(int square):
    cdef BlockerAttackTables tables
    cdef Bitboard mask = BLOCKER_MASK(square)
    cdef Bitboard tmp = Bitboard(0,0)
    cdef uint64_t merged_mask = merge(mask)

    tables.blocker = <uint64_t*>malloc((2**BLOCKER_BITS(square)) * sizeof(uint64_t))
    tables.attack = <uint64_t*>malloc((2**BLOCKER_BITS(square)) * sizeof(Bitboard))

    while True:


cdef find_magic(int square, int bits):
    uint64_t mask, blockers[16384], moves[16384], used[16384], magic
    int i, j, k, n, fail

    mask = merge(BLOCKER_MASK(square))
    n = count_bits(mask)

    for i in range(1 << n):
        b[i] = index_to_uint64(i, n, mask)
        a[i] =
"""

#==============================================================================
# Python Acessible Tests
#==============================================================================

def print_blocker_masks():
    print_masks()

def print_blocker_bits():
    print_relevant_bits()

def test():
    cdef uint64_t r = random_u64()
    cdef Bitboard board = Bitboard(r, 0)
    print(r)
    print_board(board)
#---------------------------------------------

cdef struct BlockerMoveTables:
    uint64_t* blockers
    Bitboard* moves
    size_t size

cdef Bitboard carry_rippler_next(Bitboard subset, Bitboard mask):
    cdef Bitboard next
    cdef uint64_t carry

    next.low = (subset.low - mask.low) & mask.low
    carry = (subset.low - mask.low) > subset.low
    next.high = ((subset.high - carry) - mask.high) & mask.high

    return next

cdef BlockerMoveTables build_blocker_move_tables(int square):
    cdef BlockerMoveTables tables
    cdef Bitboard mask = get_blocker_mask(square)
    cdef Bitboard subset = Bitboard(0, 0)
    cdef int index = 0

    tables.size = 1 << BLOCKER_BITS[square]
    print(BLOCKER_BITS[square])
    print(tables.size)
    tables.blockers = <uint64_t*>malloc(tables.size * sizeof(uint64_t))
    tables.moves = <Bitboard*>malloc(tables.size * sizeof(Bitboard))

    while True:
        tables.blockers[index] = merge(subset)
        tables.moves[index] = find_moves_otf(subset, square)
        index += 1
        subset = carry_rippler_next(subset, mask)
        if subset.low == 0 and subset.high == 0:
            break

    return tables

cdef void free_blocker_move_tables(BlockerMoveTables* tables):
    if tables.blockers != NULL:
        free(tables.blockers)
        tables.blockers = NULL
    if tables.moves != NULL:
        free(tables.moves)
        tables.moves = NULL
    tables.size = 0

def build_tables(int square):
    cdef Bitboard tmp = Bitboard(0,0)
    cdef BlockerMoveTables tables = build_blocker_move_tables(square)
    blockers = [tables.blockers[i] for i in range(tables.size)]
    moves = [tables.moves[i] for i in range(tables.size)]

    # Print some sample data
    tmp.low = tables.blockers[0]
    print_board(tmp)
    print_board(tables.moves[0])
    print('----------------------------------')
    tmp.low = tables.blockers[10]
    print_board(tmp)
    print_board(tables.moves[10])
    print('----------------------------------')
    tmp.low = tables.blockers[1000]
    print_board(tmp)
    print_board(tables.moves[1000])
    print('----------------------------------')
    tmp.low = tables.blockers[tables.size - 511]  # Use last valid index instead of -1
    print_board(tmp)
    print_board(tables.moves[tables.size - 511])
    print('----------------------------------')

    free_blocker_move_tables(&tables)
    return blockers, moves
