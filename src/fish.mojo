from gammaraylib import Vec2f
from std.random import random_si64
from rng import GameRng

struct Fish(ImplicitlyCopyable, Movable):
    var flop_progress_timer: Float32
    var pos: Vec2f
    var target_flop: Vec2f
    var flop_trigger_timer: Float32
    var flop_time_accumulator: Float32
    var color: UInt32  # 0 is red (speed boost), 1 is green (mass boost)

    def __init__(out self, pos: Vec2f, init_target: Vec2f, mut rng: GameRng):
        self.flop_progress_timer = 0.0
        self.pos = Vec2f(0.0, 0.0)
        self.target_flop = Vec2f(0.0, 0.0)
        self.flop_trigger_timer = 0.0
        self.flop_time_accumulator = 0.0
        self.color = 0
        self.spawn(pos, init_target, rng)

    def spawn(mut self, position: Vec2f, init_target: Vec2f, mut rng: GameRng):
        self.pos = position

        var rand_color = rng.next_int(0, 9)
        if rand_color < 5:
            self.color = 0
        else:
            self.color = 1

        # Roll dice to set threshold (rand() % 4 + 2 ->)
        self.flop_trigger_timer = Float32(rng.next_int(2, 5))

        # Start in flopping position
        self.target_flop = init_target
        self.flop_progress_timer = 1.0
        self.flop_time_accumulator = 0.0

    def flop(mut self, d_sec: Float32, mut rng: GameRng):
        # Check if we're still below the current threshold
        if self.flop_time_accumulator <= self.flop_trigger_timer:
            self.flop_time_accumulator += d_sec
        else:
            self.flop_time_accumulator -= self.flop_trigger_timer
            var rx = Float32(rng.next_int(-40, 39))
            var ry = Float32(rng.next_int(-40, 39))
            self.target_flop = Vec2f(rx, ry)
            self.flop_progress_timer = 1.0

            # Re-roll dice and set threshold (rand() % 3 + 1 ->)
            self.flop_trigger_timer = Float32(rng.next_int(1, 3))

        # Move fish toward the target
        if self.flop_progress_timer > 0.0:
            self.pos = self.pos + (self.target_flop * d_sec)
            self.flop_progress_timer -= d_sec
        else:
            self.flop_progress_timer = 0.0

    def get_position(self) -> Vec2f:
        return self.pos

    def get_color(self) -> UInt32:
        return self.color
