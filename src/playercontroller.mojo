from gammaraylib import *
from player import Player

struct PlayerController(Copyable, Movable):
    def __init__(out self):
        pass

    def update(self, rl: Raylib, mut player: Player, d_sec: Float32, player_num: Int) -> Bool:
        """
        Processes keyboard input for player 1 or player 2.
        Returns True if the pause key (P) was pressed this frame.
        """
        var dx: Float32 = 0.0
        var dy: Float32 = 0.0

        if player_num == 1:
            # Process keyboard input for Player 1 (WASD + Left Shift)
            if rl.is_key_down(KEY_W):
                dy -= 1.0
            if rl.is_key_down(KEY_S):
                dy += 1.0
            if rl.is_key_down(KEY_A):
                dx -= 1.0
            if rl.is_key_down(KEY_D):
                dx += 1.0

            if rl.is_key_down(KEY_LEFT_SHIFT) and player.get_stamina() >= 30.0:
                player.raise_tusks(d_sec)
        else:
            # Process keyboard input for Player 2 (Arrow Keys + Right Shift)
            if rl.is_key_down(KEY_UP):
                dy -= 1.0
            if rl.is_key_down(KEY_DOWN):
                dy += 1.0
            if rl.is_key_down(KEY_LEFT):
                dx -= 1.0
            if rl.is_key_down(KEY_RIGHT):
                dx += 1.0

            if rl.is_key_down(KEY_RIGHT_SHIFT) and player.get_stamina() >= 30.0:
                player.raise_tusks(d_sec)

        var dir = Vec2f(dx, dy)
        player.apply_active_force(dir, d_sec)

        # Check pause toggle (replaces SFML KeyPressed::P)
        return rl.is_key_pressed(KEY_P)
