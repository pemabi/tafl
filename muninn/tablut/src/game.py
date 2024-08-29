class TablutBitboard:
    def __init__(self):
        self.white = 0
        self.black = 0
        self.king = 0
        self.throne = 0

    def set_piece(self, row, col, piece_type):
        bit_position = row * 9 + col
        mask = 1 << bit_position

        # Clear the position on all bitboards
        self.white &= ~mask
        self.black &= ~mask
        self.king &= ~mask
        self.throne &= ~mask

        # Set the piece on the appropriate bitboard
        if piece_type == 'white':
            self.white |= mask
        elif piece_type == 'black':
            self.black |= mask
        elif piece_type == 'king':
            self.king |= mask
        elif piece_type == 'throne':
            self.throne |= mask

    def get_piece(self, row, col):
        bit_position = row * 9 + col
        mask = 1 << bit_position

        if self.white & mask:
            return 'white'
        elif self.black & mask:
            return 'black'
        elif self.king & mask:
            return 'king'
        elif self.throne & mask:
            return 'throne'
        else:
            return 'empty'

    def print_board(self):
        for row in range(9):
            for col in range(9):
                piece = self.get_piece(row, col)
                if piece == 'white':
                    print('W', end=' ')
                elif piece == 'black':
                    print('B', end=' ')
                elif piece == 'king':
                    print('K', end=' ')
                elif piece == 'throne':
                    print('T', end=' ')
                else:
                    print('.', end=' ')
            print()

    def initialize_board(self):
        # Set up the initial Tablut board state
        self.set_piece(4, 4, 'throne')
        self.set_piece(4, 4, 'king')

        # Set white pieces
        for i in [3, 4, 5]:
            self.set_piece(4, i, 'white')
            self.set_piece(i, 4, 'white')

        # Set black pieces
        black_positions = [
            (0, 3), (0, 4), (0, 5), (1, 4),
            (3, 0), (4, 0), (5, 0), (4, 1),
            (8, 3), (8, 4), (8, 5), (7, 4),
            (3, 8), (4, 8), (5, 8), (4, 7)
        ]
        for row, col in black_positions:
            self.set_piece(row, col, 'black')
