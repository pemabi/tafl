import mcts
import keras
from game import Board
from tqdm import tqdm
import numpy as np

def fst(x):
        return x[0]

class ReinfLearn():

    def __init__(self, model):
        self.model = model

    def play_game(self):
        positions_data = []
        move_probs_data = []
        values_data = []

        g = Board()
        g.set_starting_position()

        while (not fst(g.is_terminal())):
            positions_data.append(g.to_network_input_multidim())

            root_edge = mcts.Edge(None, None)
            root_edge.N = 1
            root_node = mcts.Node(g, root_edge)
            mcts_searcher = mcts.MCTS(self.model)

            move_probs = mcts_searcher.search(root_node)
            output_vec = [0.0 for x in range(0, Board.LEN_OUTPUT_INDEX)]
            for (move, prob, _, _) in move_probs:
                move_idx = g.get_network_output_index(move)
                output_vec[move_idx] = prob

            rand_idx = np.random.multinomial(1, output_vec)
            idx = np.where(rand_idx==1)[0][0]
            next_move = None

            for move, _, _, _ in move_probs:
                move_idx = g.get_network_output_index(move)
                if(move_idx == idx):
                    next_move = move
            if g.turn == Board.WHITE:
                values_data.append(1)
            else:
                values_data.append(-1)
            move_probs_data.append(output_vec)
            g.apply_move(next_move)
        else:
            _, winner = g.is_terminal()
            for i in range(0, len(move_probs_data)):
                if winner == Board.BLACK:
                    values_data[i] = values_data[i] * -1.0
                if winner == Board.WHITE:
                    values_data[i] = values_data[i] * 1.0
                if winner == Board.EMPTY:
                    values_data[i] = values_data[i] * 0.0
        return (positions_data, move_probs_data, values_data)

model = keras.models.load_model("../saved_models/supervised_model_tablut_md.keras")
mcts_searcher = mcts.MCTS(model)
learner = ReinfLearn(model)

for i in range(0, 100):
    print(f"Training Iteration: {i}")
    all_pos = []
    all_move_probs = []
    all_values = []
    for j in tqdm(range(0, 3)):
        pos, move_probs, values = learner.play_game()
        all_pos += pos
        all_move_probs += move_probs
        all_values += values

        print(pos[1])
        print(move_probs[1])

    np_pos = np.array(all_pos)
    np_probs = np.array(all_move_probs)
    np_vals = np.array(all_values)
    print(f'positions: {len(np_pos)} | probs: {len(np_probs)} | vals: {len(np_vals)}')
    model.fit(np_pos, [np_probs, np_vals], epochs = 256, batch_size=16, verbose=0)
    if i == 10:
        model.save(f'model_it{i}.keras')
