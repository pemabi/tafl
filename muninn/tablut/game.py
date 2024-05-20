import matplotlib.pyplot as plt
import numpy as np

def generate_output_index():
    """
    Creates output index for all possible Tablut moves. Returns them as a dictionary where key is string tuple "(from_sq, to_sq)" and value is unique index number:
    output_index["(0, 1)"] = 1
    """
    output_index = {}

    LEN_ROW = 9
    NUM_SQUARES = LEN_ROW**2

    index_value = 0

    def add_squares(start_square, first_square, last_square, step):
        """
        Helper function to add entries to output index.
        """
        nonlocal index_value
        for end_square in range(first_square, last_square, step):
            if end_square != start_square:
                output_index[f"({start_square}, {end_square})"] = index_value
                index_value += 1

    for start_square in range(0, NUM_SQUARES):
        # first squares in row/col of considered starting square
        first_square_row = (start_square // LEN_ROW) * 9
        first_square_col = start_square - first_square_row
        # add row moves
        add_squares(start_square=start_square, first_square=first_square_row, last_square=first_square_row+LEN_ROW, step=1)
        # add col moves
        add_squares(start_square=start_square, first_square=first_square_col, last_square=NUM_SQUARES, step=LEN_ROW)
    return output_index

class Board():
    """
    Object Board encodes all information about current position.
    """

    EMPTY = 0
    WHITE = 1
    BLACK = 2
    KING = 3
    CASTLE = 40

    EDGES = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 17, 18, 26, 27, 36, 44,
             45, 53, 54, 62, 63, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80}

    OUTPUT_INDEX = generate_output_index()
    LEN_OUTPUT_INDEX = len(OUTPUT_INDEX)


    def __init__(self):
        self.turn = self.WHITE
        self.board = [self.EMPTY] * 81
        self.legal_moves = None
        self.move_log = []

    def set_starting_position(self):
        """
        Returns board to the Tablut starting position.
        """
        self.board = [self.EMPTY, self.EMPTY, self.EMPTY, self.BLACK, self.BLACK, self.BLACK, self.EMPTY, self.EMPTY, self.EMPTY,
                    self.EMPTY, self.EMPTY, self.EMPTY, self.EMPTY, self.BLACK, self.EMPTY, self.EMPTY, self.EMPTY, self.EMPTY,
                    self.EMPTY, self.EMPTY, self.EMPTY, self.EMPTY, self.WHITE, self.EMPTY, self.EMPTY, self.EMPTY, self.EMPTY,
                    self.BLACK, self.EMPTY, self.EMPTY, self.EMPTY, self.WHITE, self.EMPTY, self.EMPTY, self.EMPTY, self.BLACK,
                    self.BLACK, self.BLACK, self.WHITE, self.WHITE, self.KING, self.WHITE, self.WHITE, self.BLACK, self.BLACK,
                    self.BLACK, self.EMPTY, self.EMPTY, self.EMPTY, self.WHITE, self.EMPTY, self.EMPTY, self.EMPTY, self.BLACK,
                    self.EMPTY, self.EMPTY, self.EMPTY, self.EMPTY, self.WHITE, self.EMPTY, self.EMPTY, self.EMPTY, self.EMPTY,
                    self.EMPTY, self.EMPTY, self.EMPTY, self.EMPTY, self.BLACK, self.EMPTY, self.EMPTY, self.EMPTY, self.EMPTY,
                    self.EMPTY, self.EMPTY, self.EMPTY, self.BLACK, self.BLACK, self.BLACK, self.EMPTY, self.EMPTY, self.EMPTY]

## TODO: fix this so that 'edge captures' aren't possible!!
    def find_captures(self, move):
        """
        Checks for any captures resulting from inputted move. Returns list of captured piece square indexes.
        """
        captures = []
        to_square = move[1]
        ally = {self.WHITE, self.KING} if self.turn == self.WHITE else {self.BLACK}
        enemy = self.WHITE if self.turn == self.BLACK else self.BLACK

        def add_captures(step):
            """
            Helper to find captures in given direction. Appends relevant captures to captures list.
            """
            enemy_index = to_square + step
            ally_index = to_square + (2 * step)
            # to avoid edge captures wrapping around the board
            if (step in [-1, 1]) and (ally_index // 9 != to_square // 9):
                return
            if 0 <= ally_index <= 80:
                # if square two over is an ally, or if it is an unoccupied castle square, check middle square.
                if self.board[ally_index] in ally or (ally_index == self.CASTLE and self.board[ally_index] != self.KING):
                    if self.board[enemy_index] == enemy:
                        captures.append(enemy_index)
                    if self.turn == self.BLACK and enemy_index not in [31, 39, 40, 41, 49] and \
                    self.board[enemy_index] == self.KING:
                        captures.append(enemy_index)


        def add_king_captures(step):
            """
            Helper to find King captures with modified conditions in / adjacent to castle. Appends relevant capture to captures list.
            """
            king_index = to_square + step
            if king_index in [31, 39, 40, 41, 49]:
                ally_index = to_square + (2 * step)
                if 0 <= ally_index <= 80:
                    if self.board[king_index] == self.KING:
                        for direction in [-9, -1, 1, 9]:
                            if 0 <= king_index + direction <= 80:
                                if self.board[king_index + direction] == self.WHITE or \
                                (self.board[king_index + direction] == self.EMPTY and king_index + direction != self.CASTLE):
                                    return
                        captures.append(king_index)

        for direction in [-9, -1, 1, 9]:
            add_captures(direction)

        if self.turn == self.BLACK:
            for direction in [-9, -1, 1, 9]:
                add_king_captures(direction)

        return captures

    def is_winning_move(self):
        """
        Checks to see if white has a winning move. Returns (first) winning move if available.
        """
        king_ix = None
        for i, piece in enumerate(self.board):
            if piece == self.KING:
                king_ix = i
        for candidate_move in self.legal_moves:
            if candidate_move[0] == king_ix and candidate_move[1] in self.EDGES:
                return candidate_move
        return None

    def apply_move(self, move):
        """
        Applies a move to the board. Takes a move as input and resets legal move 'cache'.
        """
        """
        ### Following snippet is for simulation with supervised network, where king wins were not recognised.
        if self.turn == self.WHITE:
            winning_move = self.is_winning_move()
            if winning_move:
                move = winning_move
        ###
        """
        # update move log for 4 most recent moves
        if len(self.move_log) < 6:
            self.move_log.append(move)
        else:
            self.move_log = self.move_log[1:]
            self.move_log.append(move)
        # applies move by setting 'to square' index to moved piece and 'from square' to empty
        from_square = move[0]
        to_square = move[1]
        self.board[to_square] = self.board[from_square]
        self.board[from_square] = self.EMPTY
        captures = self.find_captures(move)
        for capture_index in captures:
            self.board[capture_index] = self.EMPTY
        # switch to next player turn
        if self.turn == self.WHITE:
            self.turn = self.BLACK
        else:
            self.turn = self.WHITE
        # reset legal move cache
        self.legal_moves = None

    def generate_moves(self):
        """
        Collates and returns all legal moves for given board state.
        """
        if self.legal_moves == None:
            moves = []

            def check_square_king(from_square, stop, step):
                """
                Helper function that checks if square is a valid for king. Appends valid tuples to moves list.
                """
                for i in range(from_square+step, stop, step):
                    if self.board[i] == self.EMPTY:
                        moves.append((from_square, i))
                    else:
                        break

            def check_square(from_square, stop, step):
                """
                Helper function that checks if square is a valid for attacker/defender. Appends valid tuples to moves list.
                """
                for i in range(from_square+step, stop, step):
                    if self.board[i] == self.EMPTY:
                        if i == self.CASTLE:
                            continue
                        else:
                            moves.append((from_square, i))
                    else:
                        break

            # for every square, check to see if there is an ally occupying
            for row_start_sq in range(0, 81, 9):
                for col_start_sq in range(0, 9, 1):
                    from_square = row_start_sq + col_start_sq
                    # takes care of special cases for King piece. Also accounts for fact that KING != turn as all other pieces do
                    if self.board[from_square] == self.KING and self.turn == self.WHITE:
                        # rows
                        check_square_king(from_square=from_square, stop=from_square+9-col_start_sq, step=1)
                        check_square_king(from_square=from_square, stop=row_start_sq-1, step=-1)
                        # cols
                        check_square_king(from_square=from_square, stop=81, step=9)
                        check_square_king(from_square=from_square, stop=col_start_sq-1, step=-9)

                    if self.board[from_square] == self.turn:
                        # rows
                        check_square(from_square=from_square, stop=from_square+9-col_start_sq, step=1)
                        check_square(from_square=from_square, stop=row_start_sq-1, step=-1)
                        # cols
                        check_square(from_square=from_square, stop=81, step=9)
                        check_square(from_square=from_square, stop=col_start_sq-1, step=-9)
                self.legal_moves = moves
        return self.legal_moves

    def is_surround(self):
        """
        Determines if white pieces are surrounded to meet conditions for Black win. Returns True if surrounded, False otherwise.
        """
        searched_squares = set()

        def flood_fill(head):
            """
            Recursive DFS flood fill function to determine if the white pieces are surrounded. True if flood fill finds a white piece / king, else false
            """
            for increment in [9, -1, -9, 1]:
                tail = head + increment
                if 0 <= tail <= 80:
                    if tail not in searched_squares:
                        searched_squares.add(tail)
                        if self.board[tail] == self.WHITE or self.board[tail] == self.KING:
                            return True
                        elif self.board[tail] == self.EMPTY:
                            if flood_fill(tail):
                                return True
                        else:
                            continue
            return False

        for edge in self.EDGES:
            if self.board[edge] == self.WHITE or self.board[edge] == self.KING:
                return False
            elif edge not in searched_squares and self.board[edge] != self.BLACK:
                if flood_fill(edge):
                    return False
        return True

    # TODO: fix the surrounding logic!! How tf do I do this
    def is_terminal(self):
        """
        Detects terminal position, returns tuple (bool, int)
        """
        winner = None
        # white wins if King reaches edge
        if self.turn == self.BLACK: # terminal check occurs at beginning of each player's turn
            for edge_square in self.EDGES:
                if self.board[edge_square] == self.KING:
                    winner = self.WHITE
                    return True, winner
        # black wins by capture or surrounding
        if self.turn == self.WHITE:
            if self.KING not in self.board or self.is_surround():
                winner = self.BLACK
                return True, winner
        # stalemate by repetition
        if len(self.move_log) == 6:
            if self.move_log[0] == self.move_log[4] and self.move_log[1] == self.move_log[5]:
                return True, self.EMPTY
        return False, None

    def get_network_output_index(self, move):
        """
        For given move, returns network output index value.
        """
        return self.OUTPUT_INDEX[str(move)]

    ## TODO: can experiment with different types of input shape. Multidimensional? More/less than 9 'turn' bits?
    def to_network_input(self):
        """
        Converts board to a 1D encoding of the position. Returns bitvector summarising position.
        """
        position_vector = []
        for i in range(0, 81):
            if self.board[i] == Board.WHITE:
                position_vector.append(1)
            else:
                position_vector.append(0)
        for i in range(0, 81):
            if self.board[i] == Board.BLACK:
                position_vector.append(1)
            else:
                position_vector.append(0)
        for i in range(0, 81):
            if self.board[i] == Board.KING:
                position_vector.append(1)
            else:
                position_vector.append(0)
        for i in range(0, 9):
            if self.turn == Board.WHITE:
                position_vector.append(1)
            else:
                position_vector.append(0)
        return position_vector

    def to_network_input_multidim(self):
        """
        Converts board to a 4D encoding of position. [white, black, king, turn]
        """
        position_vector = []
        def build_bitvector(feature):
            _pos = []
            for i in range(0, 81):
                if self.board[i] == feature:
                    _pos.append(1)
                else:
                    _pos.append(0)
            return _pos
        position_vector.append(build_bitvector(Board.WHITE))
        position_vector.append(build_bitvector(Board.BLACK))
        position_vector.append(build_bitvector(Board.KING))
        _turn = []
        for i in range(0, 81):
            if self.turn == Board.WHITE:
                _turn.append(1)
            else:
                _turn.append(0)
        position_vector.append(_turn)
        return position_vector

def draw_board(board_state):
    """
    Draw the game board using matplotlib based on the given board state.
    """
    # Reshape the 1x81 list to a 9x9 list
    board_state = np.reshape(board_state, (9, 9))

    # Create a new plot
    fig, ax = plt.subplots()

    # Draw vertical lines
    for i in range(1, 9):
        plt.axvline(x=i, color='black', linewidth=2)

    # Draw horizontal lines
    for j in range(1, 9):
        plt.axhline(y=j, color='black', linewidth=2)

    # Draw the game board
    for i in range(9):
        for j in range(9):
            # Add piece if exists in the board state
            ax.text(i + 0.5, j + 0.5, str(i*9+j), color='grey', ha='center', va='center', fontsize=20, alpha=0.25)
            piece = board_state[i][j]
            if piece != 0:
                if piece == 2:
                    ax.text(i + 0.5, j + 0.5, 'B', color='black', ha='center', va='center', fontsize=20)
                elif piece == 1:
                    ax.text(i + 0.5, j + 0.5, 'W', color='red', ha='center', va='center', fontsize=20)
                else:
                    ax.text(i + 0.5, j + 0.5, 'K', color='orange', ha='center', va='center', fontsize=20)

    # Set the aspect of the plot to equal
    ax.set_aspect('equal')

    # Set the limits of the plot
    ax.set_xlim(0, 9)
    ax.set_ylim(0, 9)

    # Remove the axis
    ax.axis('off')

    # Show the plot
    plt.show()
