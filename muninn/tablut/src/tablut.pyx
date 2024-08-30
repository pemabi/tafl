# cython: language_level=3
#TODO: use all the constants I've defined
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
import random
from typing import List
from cpython cimport array
import array

# TO UPDATE CYTHON CODE USE BELOW
# python setup.py build_ext --inplace

#------------------------------------------------------------------------------
# Bitboard Struct and Mask Constants
#------------------------------------------------------------------------------
ZERO = <uint64_t>0

cdef struct Bitboard:
    uint64_t low
    uint64_t high

cdef Bitboard EMPTY_BITBOARD = Bitboard(ZERO, ZERO)

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

cdef inline Bitboard get_blocker_mask(int index):
    """
    Returns relevant blocker mask for a given square.
    """
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

cdef inline is_board_empty(Bitboard board):
    """
    Returns True if board has no bits set, else False
    """
    return board.low == 0 and board.high == 0

cdef inline same_board(Bitboard board_1, Bitboard board_2):
    """
    Returns True if two given boards have the same set bits, else False.
    """
    return board_1.low == board_2.low and board_1.high == board_2.high

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
# Find Moves on the Fly
#------------------------------------------------------------------------------
cdef Bitboard find_moves_otf(Bitboard board, int square):
    """
    Calculates moves on the fly for a given Bitboard and square. Returns Bitboard moves.
    """
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
# Generating Blocker Masks, Blocker Bits
#------------------------------------------------------------------------------
cdef Bitboard build_blocker_masks(Bitboard board, int square):
    """
    Builds a mask showing the full set of blocker squares for a given Bitboard and square. Returns Bitboard with all blockers.

    Use BLOCKER_MASK[square] instead, this was used primarily to build BLOCKER_MASK constants.
    """
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

cdef void print_relevant_bits():
    """
    Used to print BLOCKER_BITS array.
    """
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
    """
    Returns a random 64-bit ULL.

    - uses Python's random module, which returns 32 bit int. We call this twice, shifting the first random int over 32 bits for a total of 64
    """
    cdef uint64_t r = 0
    r = (random.randint(0, 0xFFFFFFFF) << 32) | random.randint(0, 0xFFFFFFFF)
    return r

cdef uint64_t random_uint64_fewbits():
    """
    Returns a sparse random 64-bit ULL.

    - we only want a few bits set, so 3 AND operations are performed. These magics are shown to be more successful.
    """
    return random_u64() & random_u64() & random_u64()

#----------------------------------------
# Magic Transformation
#----------------------------------------
cdef uint64_t transform(uint64_t key, uint64_t magic, int bits):
    """
    Applies the magic multiplation and right shift, returns a 64-bit ULL index.
    """
    return (key * magic) >> (64 - bits)

#-------------------------------------------------
# Build matching blocker subset and attack tables
#-------------------------------------------------
cdef struct BlockerMoveTables:
    uint64_t* blockers
    Bitboard* moves
    size_t size

cdef Bitboard carry_rippler_next(Bitboard subset, Bitboard mask):
    """
    Carry Rippler trick for finding subsets of a set. Returns next subset (Bitboard).
    """
    cdef Bitboard next
    cdef uint64_t carry

    next.low = (subset.low - mask.low) & mask.low
    carry = (subset.low - mask.low) > subset.low
    next.high = ((subset.high - carry) - mask.high) & mask.high

    return next

cdef BlockerMoveTables build_blocker_move_tables(int square):
    """
    Building the Blocker / Move Tables. Returns constructed tables.

    - for a square, gets relevant blocker mask
    - instantiates tables and allocates memory
    - uses Carry Rippler trick to calculate all possible subsets
    - for each subset, calculates the corresponding legal moves
    - sets table size as 2^blocker squares
    """
    cdef BlockerMoveTables tables
    cdef Bitboard mask = get_blocker_mask(square)
    cdef Bitboard subset = Bitboard(0, 0)
    cdef int index = 0

    tables.size = 1 << BLOCKER_BITS[square]
    tables.blockers = <uint64_t*>malloc(tables.size * sizeof(uint64_t))
    tables.moves = <Bitboard*>malloc(tables.size * sizeof(Bitboard))

    if tables.blockers == NULL or tables.moves == NULL:
        free_blocker_move_tables(&tables)
        raise MemoryError("Failed to allocate memory for blocker move tables")

    while True:
        tables.blockers[index] = merge(subset)
        tables.moves[index] = find_moves_otf(subset, square)
        index += 1
        subset = carry_rippler_next(subset, mask)
        if subset.low == 0 and subset.high == 0:
            break

    return tables

cdef void free_blocker_move_tables(BlockerMoveTables* tables):
    """
    Sets Blocker / Move tables to NULL and frees allocated memory.
    """
    if tables.blockers != NULL:
        free(tables.blockers)
        tables.blockers = NULL
    if tables.moves != NULL:
        free(tables.moves)
        tables.moves = NULL
    tables.size = 0

cdef uint64_t find_magic(int square):
    """
    Finds a magic number for a given square (0-80). Returns magic if succesful, else prints warning and returns an empty 64-bit ULL.

    - Creates move tables for the square
    - Creates a 'used' table for reference
    - Iterates 100M times to find magic.
    - Gets a magic candidate, filtering out unpromising candidates (with fewer than 6 of top 8 bits set).
    - Creates an index through multiplication / right shift.
    - If the index has not been used, allocates the moves to the used array.
    - If it has been used, asserts that the moves are the same, allowing for constructive collisions.
    - If a magic succesfully hashes the entire array of possible blocker configurations, the magic is returned
    """
    cdef uint64_t mask = merge(get_blocker_mask(square))
    cdef BlockerMoveTables tables = build_blocker_move_tables(square)
    cdef Bitboard* used = <Bitboard*>malloc(tables.size * sizeof(Bitboard))
    cdef n_bits = BLOCKER_BITS[square]
    cdef int k, i, index, fail, counter, max
    cdef uint64_t magic
    cdef uint64_t FAILED_MAGIC = ZERO

    if used == NULL:
        free_blocker_move_tables(&tables)
        raise MemoryError("Failed to allocate memory for used array")

    try:
        max = 0
        for k in tqdm(range(1000000000), desc="Testing Magic", unit="magic"):
            magic = random_uint64_fewbits()
            if count_bits((mask * magic) & 0xFF00000000000000) < 6:
                continue

            # Reset the used array
            for i in range(tables.size):
                used[i] = EMPTY_BITBOARD

            fail, counter = 0, 0
            while fail == 0 and counter < tables.size:
                index = transform(tables.blockers[counter], magic, n_bits)
                if is_board_empty(used[index]):
                    used[index] = tables.moves[counter]
                elif not same_board(used[index], tables.moves[counter]):
                    fail = 1
                counter += 1
                if counter > max:
                    max = counter


            if fail == 0:
                return magic

        print(f"***Failed to find Magic for square {square}. Best Magic passed first {max} entries ({max/tables.size})***")
        return FAILED_MAGIC
    finally:
        free(used)
        free_blocker_move_tables(&tables)

def find_magics(squares=None):
    """
    Python-accessible function to print magic numbers for specified board squares.

    :param squares: List or array of square indices to find magics for. If None, finds magics for all squares.
    """
    cdef array.array square_array
    cdef int square, i
    cdef uint64_t magic

    if squares is None:
        squares = range(81)

    square_array = array.array('i', squares)

    if min(square_array) < 0 or max(square_array) > 80:
        raise ValueError("Invalid square(s). Must be: 0 <= square <= 80")

    print("****FINDING MAGICS****\n")

    magics = []
    #for i in tqdm(range(len(square_array)), desc="Finding magic numbers", unit="square"):
    for i in range(len(square_array)):
        square = square_array[i]
        magic = find_magic(square)
        magics.append(f"0x{magic:016X}")

    if len(square_array) == 81 and list(square_array) == list(range(81)):
        print("cdef uint64_t Magic[81] = {")
        for i, magic in enumerate(magics):
            if i % 4 == 0 and i != 0:
                print()
            print(f"{magic},", end=" ")
        print("\n}")
    else:
        for i in range(len(square_array)):
            print(f"Square {square_array[i]} Magic: {magics[i]}")

    print("\n****COMPLETE****")

#==============================================================================
# Python Acessible Tests
#==============================================================================

def print_blocker_masks():
    """
    Python-friendly function to print BLOCKER_MASK values
    """
    print_masks()

def print_blocker_bits():
    """
    Python-friendly function to print BLOCKER_BITS values
    """
    print_relevant_bits()

def test():
    cdef uint64_t r = random_u64()
    cdef Bitboard board = Bitboard(r, 0)
    print(r)
    print_board(board)
#---------------------------------------------

def py_build_bm_tables(int square):
    """
    Python-friendly test to inspect the BlockerMoveTables. Returns BlockerMoveTable for given square.
    """
    cdef Bitboard tmp = Bitboard(0,0)
    cdef BlockerMoveTables tables = build_blocker_move_tables(square)
    blockers = [tables.blockers[i] for i in range(tables.size)]
    moves = [tables.moves[i] for i in range(tables.size)]
    free_blocker_move_tables(&tables)

    return blockers, moves
