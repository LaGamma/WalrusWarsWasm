from std.collections import List
from std.math import cos, sin, sqrt
from gammaraylib import *
from definitions import *
from fish import Fish
from player import Player
from stage import Stage, GRID_W, GRID_H

struct BotRay(ImplicitlyCopyable, Movable):
    var dir: SIMD[DType.float64, 2]
    var dist: Float64
    var obj: Int  # 1 = water, 2 = fish, 3 = opponent, 4 = repel border

    def __init__(out self, dir: SIMD[DType.float64, 2], dist: Float64 = 0.0, obj: Int = 0):
        self.dir = dir
        self.dist = dist
        self.obj = obj


struct BotController(Copyable, Movable):
    var rays: List[BotRay]
    var dir: Vec2f

    var top_wall_y: Float32
    var bottom_wall_y: Float32
    var left_wall_x: Float32
    var right_wall_x: Float32

    def __init__(out self):
        self.rays = List[BotRay]()
        self.dir = Vec2f(0.0, 0.0)
        self.top_wall_y = -50.0
        self.bottom_wall_y = WINDOW_HEIGHT + 50.0
        self.left_wall_x = -50.0
        self.right_wall_x = WINDOW_WIDTH + 50.0

    def update(
        mut self,
        mut rl: Raylib,
        mut self_walrus: Player,
        opponent_walrus: Player,
        stage: Stage,
        stage_progression: Int,
        fish_list: List[Fish],
        d_sec: Float32,
        player_num: Int,
        debug_draw: Bool = False,
    ) raises -> Bool:
        """
        Updates Bot AI steering, raycasts, and applies movement force.
        Returns True if the pause key (P) was pressed.
        """
        var self_pos = self_walrus.get_pos()
        var opponent_dead = opponent_walrus.is_dead()

        if not opponent_dead:
            # Reset repel walls
            self.top_wall_y = -50.0
            self.bottom_wall_y = WINDOW_HEIGHT + 50.0
            self.left_wall_x = -50.0
            self.right_wall_x = WINDOW_WIDTH + 50.0
        else:
            # Adapt repel walls to player position
            if self_pos[1] < self.top_wall_y:
                self.top_wall_y = self_pos[1] - 150.0
            if self_pos[1] > self.bottom_wall_y:
                self.bottom_wall_y = self_pos[1] + 150.0
            if self_pos[0] < self.left_wall_x:
                self.left_wall_x = self_pos[0] - 150.0
            if self_pos[0] > self.right_wall_x:
                self.right_wall_x = self_pos[0] + 150.0

            # Enclose repel walls
            var ice_h = Float32(ICE_BLOCKS_HEIGHT)
            if self.bottom_wall_y > (17.0 * WINDOW_HEIGHT / 30.0) + ice_h:
                self.bottom_wall_y -= d_sec * 120.0
            if self.top_wall_y < (13.0 * WINDOW_HEIGHT / 30.0) + ice_h:
                self.top_wall_y += d_sec * 120.0

            if player_num == 1 and self.right_wall_x > 0.0:
                self.right_wall_x -= d_sec * 120.0
            elif player_num == 2 and self.left_wall_x < WINDOW_WIDTH:
                self.left_wall_x += d_sec * 120.0

        self.calculate_rays(self_walrus, opponent_walrus, stage, stage_progression, fish_list)
        self.calculate_force(self_walrus, opponent_walrus)

        if debug_draw:
            # Draw repel border (Black)
            var black = Vec4f(0.0, 0.0, 0.0, 1.0)
            rl.draw_line(self.left_wall_x, self.bottom_wall_y, self.right_wall_x, self.bottom_wall_y, black)
            rl.draw_line(self.right_wall_x, self.bottom_wall_y, self.right_wall_x, self.top_wall_y, black)
            rl.draw_line(self.right_wall_x, self.top_wall_y, self.left_wall_x, self.top_wall_y, black)
            rl.draw_line(self.left_wall_x, self.top_wall_y, self.left_wall_x, self.bottom_wall_y, black)

            # Draw rays (Blue)
            var blue = Vec4f(0.0, 0.0, 1.0, 1.0)
            for i in range(len(self.rays)):
                var r = self.rays[i]
                var end_x = self_pos[0] + Float32(r.dir[0] * r.dist)
                var end_y = self_pos[1] + Float32(r.dir[1] * r.dist)
                rl.draw_line(self_pos[0], self_pos[1], end_x, end_y, blue)

            # Draw direction line (Red)
            var red = Vec4f(1.0, 0.0, 0.0, 1.0)
            rl.draw_line(self_pos[0], self_pos[1], self_pos[0] + self.dir[0], self_pos[1] + self.dir[1], red)

        var dx64 = Float64(self.dir[0])
        var dy64 = Float64(self.dir[1])
        var angst_magnitude = sqrt((dx64 * dx64) + (dy64 * dy64))

        if angst_magnitude > 0.0001:
            var ux = Float32(dx64 / angst_magnitude)
            var uy = Float32(dy64 / angst_magnitude)
            if angst_magnitude > 30.0 and not opponent_dead:
                self.dir = Vec2f(ux, uy)
            elif angst_magnitude > 60.0:
                self.dir = Vec2f(ux, uy)
            else:
                self.dir = Vec2f(ux / 4.0, uy / 4.0)
        else:
            self.dir = Vec2f(0.0, 0.0)

        # Don't apply movement force if called in pause/debug mode (d_sec == 0)
        if d_sec > 0.0:
            self_walrus.apply_active_force(self.dir, d_sec)

        return rl.is_key_pressed(KEY_P)

    def calculate_rays(
        mut self,
        self_walrus: Player,
        opponent_walrus: Player,
        stage: Stage,
        stage_progression: Int,
        fish_list: List[Fish],
    ):
        var opponent_dead = opponent_walrus.is_dead()
        var opp_pos_f = opponent_walrus.get_pos()
        var self_pos_f = self_walrus.get_pos()

        var opponent_pos = SIMD[DType.float64, 2](Float64(opp_pos_f[0]), Float64(opp_pos_f[1]))
        var self_pos = SIMD[DType.float64, 2](Float64(self_pos_f[0]), Float64(self_pos_f[1]))

        self.rays.clear()

        var tile_size = Float64(ICE_BLOCKS_SIZE_Y)
        var pi64 = Float64(PI)

        for i in range(NUM_OF_RAYS_CAST):
            var angle = (360.0 / Float64(NUM_OF_RAYS_CAST)) * Float64(i)
            var rad = angle * pi64 / 180.0
            var unit_vec = SIMD[DType.float64, 2](cos(rad), sin(rad))
            var step = unit_vec / 10.0
            var projection = self_pos + step

            if not opponent_dead:
                while True:
                    var tx = Int(projection[0] / tile_size)
                    var ty = Int(projection[1] / tile_size)
                    if tx < 0 or tx >= GRID_W or ty < 0 or ty >= GRID_H:
                        break
                    if stage.get_tile_dura(tx, ty, stage_progression) <= 0.4:
                        break
                    projection = projection + step

                var delta = projection - self_pos
                var magnitude = sqrt(delta[0] * delta[0] + delta[1] * delta[1])
                self.rays.append(BotRay(unit_vec, magnitude, 1))
            else:
                var hit_water: Bool
                while True:
                    var tx = Int(projection[0] / tile_size)
                    var ty = Int(projection[1] / tile_size)
                    if tx < 0 or tx >= GRID_W or ty < 0 or ty >= GRID_H:
                        hit_water = True
                        break
                    if stage.get_tile_dura(tx, ty, stage_progression) <= 0.4:
                        hit_water = True
                        break
                    if (
                        projection[0] <= Float64(self.left_wall_x)
                        or projection[0] >= Float64(self.right_wall_x)
                        or projection[1] <= Float64(self.top_wall_y)
                        or projection[1] >= Float64(self.bottom_wall_y)
                    ):
                        hit_water = False
                        break
                    projection = projection + step

                var delta = projection - self_pos
                var magnitude = sqrt(delta[0] * delta[0] + delta[1] * delta[1])
                # Note: matches original C++ logic where hitting water inside walls gives obj 1, hitting wall gives obj 4
                var obj_type = 1 if hit_water else 4
                self.rays.append(BotRay(unit_vec, magnitude, obj_type))

        # Calculate and add fish rays (obj = 2)
        for i in range(len(fish_list)):
            var fp = fish_list[i].get_position()
            var fish_pos = SIMD[DType.float64, 2](Float64(fp[0]), Float64(fp[1]))
            var pos_diff = fish_pos - self_pos
            var magnitude = sqrt((pos_diff[0] * pos_diff[0]) + (pos_diff[1] * pos_diff[1]))
            if magnitude > 0.0001:
                var unit_vec = SIMD[DType.float64, 2](pos_diff[0] / magnitude, pos_diff[1] / magnitude)
                self.rays.append(BotRay(unit_vec, magnitude, 2))

        # Calculate and add opponent ray (obj = 3 if alive, 4 if dead)
        var opp_diff = opponent_pos - self_pos
        var opp_mag = sqrt((opp_diff[0] * opp_diff[0]) + (opp_diff[1] * opp_diff[1]))
        if opp_mag > 0.0001:
            var unit_vec = SIMD[DType.float64, 2](opp_diff[0] / opp_mag, opp_diff[1] / opp_mag)
            var opp_obj = 3 if not opponent_dead else 4
            self.rays.append(BotRay(unit_vec, opp_mag, opp_obj))

    def calculate_force(mut self, self_walrus: Player, opponent_walrus: Player):
        var opponent_dead = opponent_walrus.is_dead()
        var opponent_vel = opponent_walrus.get_vel()
        var self_vel = self_walrus.get_vel()

        var pop_vec = SIMD[DType.float64, 2](0.0, 0.0)

        for i in range(len(self.rays)):
            var r = self.rays[i]
            if r.obj == 1:  # Water -> repel
                pop_vec = pop_vec - (r.dir * ((100.0 * (0.99 ** r.dist)) + 10.0))
            elif r.obj == 2:  # Fish -> attract
                if not opponent_dead:
                    pop_vec = pop_vec + (r.dir * ((100.0 * (0.97 ** r.dist)) + 10.0))
                else:
                    pop_vec = pop_vec + (r.dir * (50.0 * (0.97 ** r.dist)))
            elif r.obj == 3:  # Opponent -> attack if velocity advantage, flee if disadvantage
                var opp_fc_x = opponent_vel[0] * Float32(-r.dir[0])
                var opp_fc_y = opponent_vel[1] * Float32(-r.dir[1])
                var self_fc_x = self_vel[0] * Float32(r.dir[0])
                var self_fc_y = self_vel[1] * Float32(r.dir[1])

                var diff_x = self_fc_x - opp_fc_x
                var diff_y = self_fc_y - opp_fc_y

                if diff_x > 30.0 or diff_y > 30.0:
                    pop_vec = pop_vec + (r.dir * ((100.0 * (0.99 ** r.dist)) + 10.0))
                elif diff_x < -30.0 or diff_y < -30.0:
                    pop_vec = pop_vec - (r.dir * ((100.0 * (0.99 ** r.dist)) + 10.0))
            elif r.obj == 4:  # Repel border -> repel strongly
                pop_vec = pop_vec - (r.dir * ((200.0 * (0.99 ** r.dist)) + 10.0))

        self.dir = pop_vec.cast[DType.float32]()
