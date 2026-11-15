from gammaraylib import Rectangle, Texture2D, Vec2f
from player import PlayerState

struct Animation(ImplicitlyCopyable, Movable):
    var uv_rect: Rectangle
    var sprite_count_x: Int
    var sprite_count_y: Int
    var current_sprite: Vec2f
    var total_time: Float32
    var switch_time: Float32
    var row: Int
    var flip: Bool

    def __init__(out self):
        self.uv_rect = Rectangle(0.0, 0.0, 0.0, 0.0)
        self.sprite_count_x = 1
        self.sprite_count_y = 1
        self.current_sprite = Vec2f(0.0, 0.0)
        self.total_time = 0.0
        self.switch_time = 0.1
        self.row = 0
        self.flip = False

    def init(mut self, texture: Texture2D, sprite_count_x: Int, sprite_count_y: Int, switch_time: Float32):
        self.sprite_count_x = sprite_count_x
        self.sprite_count_y = sprite_count_y
        self.switch_time = switch_time
        self.total_time = 0.0
        self.current_sprite = Vec2f(0.0, 0.0)
        self.uv_rect = Rectangle(
            0.0,
            0.0,
            Float32(texture.width) / Float32(sprite_count_x),
            Float32(texture.height) / Float32(sprite_count_y),
        )

    def update_walrus(mut self, dir: Vec2f, state: PlayerState, d_sec: Float32):
        var cx = self.current_sprite[0]
        var cy = self.current_sprite[1]

        # Convert direction vector into direction hash
        var hash = Int(dir[0] * 17.0 + dir[1] * 7.0)
        if hash == 17 + 7:      # right down
            cy = 4.0
            self.row = 4
            self.flip = True
        elif hash == 17 - 7:    # right up
            cy = 3.0
            self.row = 3
            self.flip = True
        elif hash == -17 + 7:   # left down
            cy = 4.0
            self.row = 4
            self.flip = False
        elif hash == -17 - 7:   # left up
            cy = 3.0
            self.row = 3
            self.flip = False
        elif hash == 17:        # right
            cy = 2.0
            self.row = 2
            self.flip = True
        elif hash == 7:         # down
            cy = 0.0
            self.row = 0
            self.flip = False
        elif hash == -17:       # left
            cy = 2.0
            self.row = 2
            self.flip = False
        elif hash == -7:        # up
            cy = 1.0
            self.row = 1
            self.flip = False

        var max_cols = Float32(self.sprite_count_x)

        # Handle animation progression based on player state
        if state == PlayerState.IDLE:
            self.set_current_sprite(0, 0, False)
            return
        elif state == PlayerState.RESTING:
            self.total_time += d_sec
            cy = 10.0
            if self.total_time >= self.switch_time * 2.0:
                self.total_time -= self.switch_time * 2.0
                cx += 1.0
                if cx >= max_cols:
                    cx = 0.0
        elif state == PlayerState.RAISING_TUSKS:
            self.total_time += d_sec
            cy = Float32(self.row + 5)
            if self.total_time >= self.switch_time:
                self.total_time -= self.switch_time
                cx += 1.0
                if cx >= max_cols:
                    cx = 0.0
                if cx == 2.0:
                    cx = 1.0
        elif state == PlayerState.ATTACKING:
            self.total_time += d_sec
            cy = Float32(self.row + 5)
            if self.total_time >= self.switch_time:
                self.total_time -= self.switch_time
                cx -= 1.0
                if cx <= 0.0:
                    cx = max_cols - 1.0
                if cx == 1.0:
                    cx = 2.0
        elif state == PlayerState.RUNNING:
            self.total_time += d_sec
            if self.total_time >= self.switch_time:
                self.total_time -= self.switch_time
                cx += 1.0
                if cx >= max_cols:
                    cx = 0.0

        self.current_sprite = Vec2f(cx, cy)

        # Apply UV rectangle and horizontal flip
        var frame_w = abs(self.uv_rect.width)
        var frame_h = self.uv_rect.height
        if self.flip:
            self.uv_rect.x = (cx + 1.0) * frame_w
            self.uv_rect.width = -frame_w
        else:
            self.uv_rect.x = cx * frame_w
            self.uv_rect.width = frame_w
        self.uv_rect.y = cy * frame_h

    def _update_looping_row(mut self, d_sec: Float32):
        self.total_time += d_sec
        var cx = self.current_sprite[0]
        var cy = self.current_sprite[1]

        if self.total_time >= self.switch_time:
            self.total_time -= self.switch_time
            cx += 1.0
            if cx >= Float32(self.sprite_count_x):
                cx = 0.0

        self.current_sprite = Vec2f(cx, cy)
        var frame_w = abs(self.uv_rect.width)
        self.uv_rect.y = cy * self.uv_rect.height
        self.uv_rect.x = cx * frame_w
        self.uv_rect.width = frame_w

    def update_fish(mut self, d_sec: Float32):
        self._update_looping_row(d_sec)

    def update_round_fire(mut self, d_sec: Float32):
        self._update_looping_row(d_sec)

    def update_walrus_splash(mut self, d_sec: Float32):
        self._update_looping_row(d_sec)

    def update_water(mut self, d_sec: Float32):
        self._update_looping_row(d_sec)

    def set_current_sprite(mut self, x: Int, y: Int, flip: Bool):
        var cx = Float32(x)
        var cy = Float32(y)
        self.current_sprite = Vec2f(cx, cy)
        self.row = y
        self.flip = flip

        var frame_w = abs(self.uv_rect.width)
        self.uv_rect.y = cy * self.uv_rect.height
        if flip:
            self.uv_rect.x = (cx + 1.0) * frame_w
            self.uv_rect.width = -frame_w
        else:
            self.uv_rect.x = cx * frame_w
            self.uv_rect.width = frame_w

    def set_current_sprite_y(mut self, y: Int):
        self.current_sprite = Vec2f(self.current_sprite[0], Float32(y))
