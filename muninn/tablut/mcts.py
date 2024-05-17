import copy
import numpy as np
import math
from game import Board
import random

class Edge():
    """
    Object representing the 'connection' between nodes - ie action that moves from one state to another.
    """
    def __init__(self, move, parent_node):
        self.parent_node = parent_node
        self.move = move
        # How many times Node is visited
        self.N = 0
        # Total reward
        self.W = 0
        # Total reward / number of Node visits
        self.Q = 0
        # Initial probability provided by network during expansion
        self.P = 0

class Node():
    """
    Represents gamestate. Has parent edge, parent node, child edge(s) and child node(s)
    """
    def __init__(self, board, parent_edge):
        self.board = board
        self.parent_edge = parent_edge
        self.child_edge_node = []

    def expand(self, network):
        """
        Expands search tree down from node, creating new child edges and nodes.
        """
        moves = self.board.generate_moves()
        for m in moves:
            child_board = copy.deepcopy(self.board)
            child_board.apply_move(m)
            child_edge = Edge(m, self)
            child_node = Node(child_board, child_edge)
            self.child_edge_node.append((child_edge, child_node))
        # uses the model to store move probabilities and values for each edge (move)
        q = network.predict(np.array([self.board.to_network_input_multidim()]))
        prob_sum = 0.
        for (edge, _) in self.child_edge_node:
            m_idx = self.board.get_network_output_index(edge.move)
            edge.P = q[0][0][m_idx]
            prob_sum += edge.P
        for edge,_ in self.child_edge_node:
            edge.P /= prob_sum
        v = q[1][0][0]
        # returns value head so we can use this during backpropagation
        return v

    def is_leaf(self):
        """
        Checks to see whether Node has been expanded.
        """
        return self.child_edge_node == []

class MCTS():
    """
    MCT Searcher
    """
    def __init__(self, network):
        self.network = network
        self.root_node = None
        # controls the balance between exploration and exploitation
        self.tau = 1.0
        self.c_puct = 1.0

    def uct_value(self, edge, parent_N):
        """
        Computes and returns UCT value for an edge
        """
        return self.c_puct * edge.P * (math.sqrt(parent_N) / (1+edge.N))

    def select(self, node):
        if node.is_leaf():
            return node
        else:
            max_uct_child = None
            max_uct_value = -10000000.
            for edge, child_node in node.child_edge_node:
                uct_val = self.uct_value(edge, edge.parent_node.parent_edge.N)
                val = edge.Q
                if edge.parent_node.board.turn == Board.BLACK:
                    val = -edge.Q
                uct_val_child = val + uct_val
                if uct_val_child > max_uct_value:
                    max_uct_child = child_node
                    max_uct_value = uct_val_child
            # to store best children in case mutliple have same uct score
            all_best_childs = []
            for edge, child_node in node.child_edge_node:
                uct_val = self.uct_value(edge, edge.parent_node.parent_edge.N)
                val = edge.Q
                if edge.parent_node.board.turn == Board.BLACK:
                    val = edge.Q
                    uct_val_child = val + uct_val
                    if uct_val_child == max_uct_value:
                        all_best_childs.append(child_node)
            # if no child found
            if max_uct_child == None:
                raise ValueError('unable to identify child with best uct value')
            else:
                # randomly selects one of best child if there are tied scores, otherwise returns top scoring child
                if len(all_best_childs) > 1:
                    idx = random.randint(0, len(all_best_childs)-1)
                    return self.select(all_best_childs[idx])
                else:
                    return self.select(max_uct_child)

    def expand_and_evaluate(self, node):
        """
        Combined expansion and evaluation. If node is terminal, passes the reward back up the tree to the root node.
        """
        # if terminal, returns value and backpropagates
        terminal, winner = node.board.is_terminal()
        if terminal == True:
            v = 0.0
            if winner == Board.WHITE:
                v = 1.0
            if winner == Board.BLACK:
                v = -1.0
            self.backpropagate(v, node.parent_edge)
            return
        # otherwise, expands node, receiving eval value for the node, propagates this back up the tree
        v = node.expand(self.network)
        self.backpropagate(v, node.parent_edge)

    def backpropagate(self, v, edge):
        # add one visit count
        edge.N += 1
        # update reward
        edge.W = edge.W + v
        # update reward / visits
        edge.Q = edge.W / edge.N
        # if edge has parent node, recursively repeats backpropagation and updates vals
        if edge.parent_node != None:
            if edge.parent_node.parent_edge != None:
                self.backpropagate(v, edge.parent_node.parent_edge)

    def search(self, root_node):
        self.root_node = root_node
        _ = self.root_node.expand(self.network)
        for i in range(0, 100):
            selected_node = self.select(root_node)
            self.expand_and_evaluate(selected_node)
            N_sum = 0
            move_probs = []
            for edge, _ in root_node.child_edge_node:
                N_sum += edge.N
            for (edge, node) in root_node.child_edge_node:
                prob = (edge.N ** (1 / self.tau)) / ((N_sum) ** (1/self.tau))
                move_probs.append((edge.move, prob, edge.N, edge.Q))
            return move_probs
