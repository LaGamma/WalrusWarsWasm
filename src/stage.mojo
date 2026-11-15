from std.collections import Array
from definitions import ICE_BLOCKS_WIDTH, ICE_BLOCKS_HEIGHT
from rng import GameRng

comptime GRID_W: Int = ICE_BLOCKS_WIDTH + 2
comptime GRID_H: Int = ICE_BLOCKS_HEIGHT + 2
comptime GRID_SIZE: Int = GRID_W * GRID_H


@always_inline
def idx(x: Int, y: Int) -> Int:
    return x * GRID_H + y


struct Stage(Copyable, Movable):
    var center_stage: Array[Float32, GRID_SIZE]
    var left_stage_1: Array[Float32, GRID_SIZE]
    var right_stage_1: Array[Float32, GRID_SIZE]
    var left_stage_2: Array[Float32, GRID_SIZE]
    var right_stage_2: Array[Float32, GRID_SIZE]

    def __init__(out self):
        self.center_stage = Array[Float32, GRID_SIZE](fill=0.0)
        self.left_stage_1 = Array[Float32, GRID_SIZE](fill=0.0)
        self.right_stage_1 = Array[Float32, GRID_SIZE](fill=0.0)
        self.left_stage_2 = Array[Float32, GRID_SIZE](fill=0.0)
        self.right_stage_2 = Array[Float32, GRID_SIZE](fill=0.0)

    def generate_map(mut self, mut rng: GameRng):
        for i in range(GRID_W):
            for j in range(GRID_H):
                var k = idx(i, j)

                if (
                    i > (8 * ICE_BLOCKS_WIDTH) // 40
                    and i <= (32 * ICE_BLOCKS_WIDTH) // 40
                    and j > (2 * ICE_BLOCKS_HEIGHT) // 30
                    and j <= (28 * ICE_BLOCKS_HEIGHT) // 30
                ):
                    self.center_stage[k] = 1.0
                    self.left_stage_1[k] = 1.0
                    self.left_stage_2[k] = 1.0
                    self.right_stage_1[k] = 1.0
                    self.right_stage_2[k] = 1.0

                    var r = rng.next_int(0, 19)
                    if r > 15 and (
                        (j > (2 * ICE_BLOCKS_HEIGHT) // 30 and j < (4 * ICE_BLOCKS_HEIGHT) // 30)
                        or (j > (26 * ICE_BLOCKS_HEIGHT) // 30 and j <= (28 * ICE_BLOCKS_HEIGHT) // 30)
                        or (i > (8 * ICE_BLOCKS_WIDTH) // 40 and i < (10 * ICE_BLOCKS_WIDTH) // 40)
                        or (i > (30 * ICE_BLOCKS_WIDTH) // 40 and i <= (32 * ICE_BLOCKS_WIDTH) // 40)
                    ):
                        self.center_stage[k] = 0.0

                    if r > 12 and (
                        (j > (2 * ICE_BLOCKS_HEIGHT) // 30 and j < (6 * ICE_BLOCKS_HEIGHT) // 30)
                        or (j > (24 * ICE_BLOCKS_HEIGHT) // 30 and j <= (28 * ICE_BLOCKS_HEIGHT) // 30)
                        or (i > (8 * ICE_BLOCKS_WIDTH) // 40 and i < (12 * ICE_BLOCKS_WIDTH) // 40)
                        or (i > (28 * ICE_BLOCKS_WIDTH) // 40 and i <= (32 * ICE_BLOCKS_WIDTH) // 40)
                    ):
                        self.left_stage_1[k] = 0.0
                        self.right_stage_1[k] = 0.0

                    if r > 9 and (
                        (j > (2 * ICE_BLOCKS_HEIGHT) // 30 and j < (8 * ICE_BLOCKS_HEIGHT) // 30)
                        or (j > (22 * ICE_BLOCKS_HEIGHT) // 30 and j <= (28 * ICE_BLOCKS_HEIGHT) // 30)
                        or (i > (8 * ICE_BLOCKS_WIDTH) // 40 and i < (14 * ICE_BLOCKS_WIDTH) // 40)
                        or (i > (26 * ICE_BLOCKS_WIDTH) // 40 and i <= (32 * ICE_BLOCKS_WIDTH) // 40)
                    ):
                        self.left_stage_2[k] = 0.0
                        self.right_stage_2[k] = 0.0
                else:
                    var r = rng.next_int(1, 10)
                    var val: Float32 = 1.0 if r > 8 else 0.0
                    self.center_stage[k] = val
                    self.left_stage_1[k] = val
                    self.right_stage_1[k] = val
                    self.left_stage_2[k] = val
                    self.right_stage_2[k] = val

                    if (
                        i == (31 * ICE_BLOCKS_WIDTH) // 40
                        or j == (26 * ICE_BLOCKS_HEIGHT) // 30
                        or i == (10 * ICE_BLOCKS_WIDTH) // 40
                        or j == (5 * ICE_BLOCKS_HEIGHT) // 30
                    ):
                        self.center_stage[k] = 0.0

                # Build bridges on each stage
                if j > (13 * ICE_BLOCKS_HEIGHT) // 30 and j <= (17 * ICE_BLOCKS_HEIGHT) // 30:
                    self.center_stage[k] = 1.0
                    self.left_stage_1[k] = 1.0
                    self.right_stage_1[k] = 1.0
                    if i > (20 * ICE_BLOCKS_WIDTH) // 40:
                        self.left_stage_2[k] = 1.0
                    if i < (20 * ICE_BLOCKS_WIDTH) // 40:
                        self.right_stage_2[k] = 1.0

    @staticmethod
    def _melt_grid(mut grid: Array[Float32, GRID_SIZE], mut rng: GameRng):
        for i in range(1, GRID_W - 1):
            for j in range(1, GRID_H - 1):
                var k = idx(i, j)
                if grid[k] > 0.0:
                    var r = rng.next_int(1, 100)
                    var sum: Float32 = (
                        min(grid[idx(i - 1, j)], 1.0)
                        + min(grid[idx(i + 1, j)], 1.0)
                        + min(grid[idx(i - 1, j - 1)], 1.0)
                        + min(grid[idx(i - 1, j + 1)], 1.0)
                        + min(grid[idx(i + 1, j - 1)], 1.0)
                        + min(grid[idx(i + 1, j + 1)], 1.0)
                        + min(grid[idx(i, j + 1)], 1.0)
                        + min(grid[idx(i, j - 1)], 1.0)
                    )

                    var off_bridge = (
                        j <= (13 * ICE_BLOCKS_HEIGHT) // 30
                        or j > (17 * ICE_BLOCKS_HEIGHT) // 30
                    )

                    if off_bridge:
                        if sum >= 6.0:
                            if r > 99:
                                grid[k] -= 0.05
                        elif sum >= 4.0:
                            if r > 60:
                                grid[k] -= 0.05
                        elif sum >= 2.0:
                            if r > 30:
                                grid[k] -= 0.05
                        else:
                            if r > 10:
                                grid[k] -= 0.05

                if grid[k] < 0.0:
                    grid[k] = 0.0

    def tick_melt(mut self, stage: Int, mut rng: GameRng):
        if stage == -2:
            Self._melt_grid(self.left_stage_2, rng)
        elif stage == -1:
            Self._melt_grid(self.left_stage_1, rng)
        elif stage == 0:
            Self._melt_grid(self.center_stage, rng)
        elif stage == 1:
            Self._melt_grid(self.right_stage_1, rng)
        elif stage == 2:
            Self._melt_grid(self.right_stage_2, rng)

    def get_tile_dura(self, x: Int, y: Int, stage: Int) -> Float32:
        var k = idx(x, y)
        if stage == -2:
            return self.left_stage_2[k]
        elif stage == -1:
            return self.left_stage_1[k]
        elif stage == 0:
            return self.center_stage[k]
        elif stage == 1:
            return self.right_stage_1[k]
        elif stage == 2:
            return self.right_stage_2[k]
        return 0.0
