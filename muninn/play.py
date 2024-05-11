from tablut.game import Board, generate_output_index

output_index = generate_output_index()
board = Board(output_index)
board.set_starting_position()

print(board.board)
