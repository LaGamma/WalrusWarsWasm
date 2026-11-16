from std.collections import List
from std.math import sqrt
from gammaraylib import Vec2f, Vec4f
from definitions import *
from fish import Fish
from player import Player, PlayerState
from stage import Stage, GRID_W, GRID_H
from rng import GameRng

struct GameStateEnum(Copyable, Equatable, ImplicitlyCopyable, Movable):
    var value: Int

    comptime MAIN_MENU          = Self(0)
    comptime PLAYING            = Self(1)
    comptime PAUSE_MENU         = Self(2)
    comptime HELP_MENU          = Self(3)
    comptime GAME_OVER_MENU     = Self(4)
    comptime OPTIONS_MENU       = Self(5)
    comptime PLAYER_SELECT_MENU = Self(6)
    comptime NAME_TEXT_SUBMENU  = Self(7)
    comptime COLOR_SELECT_SUBMENU = Self(8)
    comptime STATS_MENU         = Self(9)

    def __init__(out self, value: Int):
        self.value = value

    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    def __ne__(self, other: Self) -> Bool:
        return self.value != other.value


struct GameLogic(Copyable, Movable):
    var winner1: Bool
    var p1_attack_handling_in_progress: Bool
    var p2_attack_handling_in_progress: Bool
    var player_bump: Float32
    var border_bump: Float32
    var player_hit: Float32
    var splash: Float32
    var powerup: Float32

    var walrus1: Player
    var walrus2: Player
    var stage: Stage
    var round: Int

    var player_collision_point: Vec2f
    var p1_attack_point: Vec2f
    var p2_attack_point: Vec2f

    var fish_list: List[Fish]

    var state: GameStateEnum
    var progression: Int
    var accumulator: Float32
    var fish_accumulator: Float32
    var sfx_volume: Float32
    var music_volume: Float32

    var rng: GameRng

    def __init__(out self):
        self.winner1 = False
        self.p1_attack_handling_in_progress = False
        self.p2_attack_handling_in_progress = False
        self.player_bump = 0.0
        self.border_bump = 0.0
        self.player_hit = 0.0
        self.splash = 0.0
        self.powerup = 0.0

        self.walrus1 = Player()
        self.walrus2 = Player()
        self.stage = Stage()
        self.round = 1

        self.player_collision_point = Vec2f(0.0, 0.0)
        self.p1_attack_point = Vec2f(0.0, 0.0)
        self.p2_attack_point = Vec2f(0.0, 0.0)

        self.fish_list = List[Fish]()

        self.state = GameStateEnum.MAIN_MENU
        self.progression = 0
        self.accumulator = 0.0
        self.fish_accumulator = 0.0
        self.sfx_volume = SFX_VOLUME_BASE
        self.music_volume = MUSIC_VOLUME_BASE

        self.rng = GameRng(12345)

    def init(mut self):
        self.state = GameStateEnum.MAIN_MENU
        self.walrus1.reset_stats()
        self.walrus2.reset_stats()
        self.stage.generate_map(self.rng)
        self.progression = 0
        self.accumulator = 0.0
        self.fish_accumulator = 0.0
        self.sfx_volume = SFX_VOLUME_BASE
        self.music_volume = MUSIC_VOLUME_BASE
        self.walrus1.set_color(Vec4f(1.0, 1.0, 1.0, 1.0))
        self.walrus2.set_color(Vec4f(155.0 / 255.0, 155.0 / 255.0, 155.0 / 255.0, 1.0))
        self.walrus1.set_name(String(DEFAULT_NAME_1))
        self.walrus2.set_name(String(DEFAULT_NAME_2))

    def _tile_dura_at_pos(self, pos: Vec2f) -> Float32:
        var tx = Int(pos[0] / ICE_BLOCKS_SIZE_X)
        var ty = Int(pos[1] / ICE_BLOCKS_SIZE_Y)
        if tx < 0 or tx >= GRID_W or ty < 0 or ty >= GRID_H:
            return 0.0
        return self.stage.get_tile_dura(tx, ty, self.progression)

    def update(mut self, d_sec: Float32):
        if self.state != GameStateEnum.PLAYING:
            return

        # Fish power-up generation (spawn in water flopping toward ice)
        self.fish_accumulator += d_sec
        if len(self.fish_list) < MAX_NUM_OF_FISH and self.fish_accumulator > 3.0:
            self.fish_accumulator = 0.0

            var max_rx = Int(7.0 * WINDOW_WIDTH / 8.0) - 1
            var max_ry = Int(5.0 * WINDOW_WIDTH / 8.0) - 1
            var off_x = WINDOW_WIDTH / 8.0
            var off_y = WINDOW_WIDTH / 8.0

            var rand_spawn = Vec2f(
                Float32(self.rng.next_int(0, max_rx)) + off_x,
                Float32(self.rng.next_int(0, max_ry)) + off_y,
            )
            var rand_target = Vec2f(
                Float32(self.rng.next_int(-80, 79)),
                Float32(self.rng.next_int(-80, 79)),
            )

            # Ensure first jump starts in water (<= 0) and lands on ice (> 0)
            var tries = 0
            while tries < 200 and (
                self._tile_dura_at_pos(rand_spawn) > 0.0
                or self._tile_dura_at_pos(rand_spawn + rand_target) <= 0.0
            ):
                rand_spawn = Vec2f(
                    Float32(self.rng.next_int(0, max_rx)) + off_x,
                    Float32(self.rng.next_int(0, max_ry)) + off_y,
                )
                rand_target = Vec2f(
                    Float32(self.rng.next_int(-80, 79)),
                    Float32(self.rng.next_int(-80, 79)),
                )
                tries += 1

            self.fish_list.append(Fish(rand_spawn, rand_target, self.rng))

        # Process movement
        if not self.walrus1.is_dead():
            self.walrus1.tick_update(d_sec)
            self.walrus1.apply_passive_force(d_sec)
        if not self.walrus2.is_dead():
            self.walrus2.tick_update(d_sec)
            self.walrus2.apply_passive_force(d_sec)

        # Melt stage
        self.accumulator += d_sec
        if self.accumulator >= 0.6:
            self.stage.tick_melt(self.progression, self.rng)
            self.accumulator -= 0.6

        # --- Check Collisions ---
        var w1_pos = self.walrus1.get_pos()
        var w2_pos = self.walrus2.get_pos()
        var w1_mass = self.walrus1.get_mass()
        var w2_mass = self.walrus2.get_mass()

        # Player 1 - water collision
        if self._tile_dura_at_pos(w1_pos) <= 0.0:
            if not self.walrus1.is_dead():
                self.handle_player_death(1)
                self.splash = self.sfx_volume

        # Player 2 - water collision
        if self._tile_dura_at_pos(w2_pos) <= 0.0:
            if not self.walrus2.is_dead():
                self.handle_player_death(2)
                self.splash = self.sfx_volume

        # Player - boundary collision
        if w1_pos[0] >= WINDOW_WIDTH or w1_pos[0] <= 0.0:
            self.handle_boundary_collision(1, w1_pos[0])
        elif w2_pos[0] >= WINDOW_WIDTH or w2_pos[0] <= 0.0:
            self.handle_boundary_collision(2, w2_pos[0])

        # Player - player collision
        var pos_diff = w1_pos - w2_pos
        var dist = sqrt((pos_diff[0] * pos_diff[0]) + (pos_diff[1] * pos_diff[1]))
        if dist < PLAYER_HITBOX_SCALE * (w1_mass + w2_mass) and not (self.walrus1.is_dead() or self.walrus2.is_dead()):
            self.handle_player_collision()

        # Player 1 attack - Player 2 collision
        if self.walrus1.get_state() == PlayerState.ATTACKING:
            self.p1_attack_point = w1_pos + (self.walrus1.get_facing_dir() * (w1_mass / 3.0))
            pos_diff = w2_pos - self.p1_attack_point
            dist = sqrt((pos_diff[0] * pos_diff[0]) + (pos_diff[1] * pos_diff[1]))
            if not self.p1_attack_handling_in_progress and dist <= PLAYER_HITBOX_SCALE * (w2_mass + w1_mass):
                if dist > 0.0001:
                    self.handle_player_attack(1, pos_diff / dist)
            elif dist > PLAYER_HITBOX_SCALE * (w2_mass + w1_mass):
                self.p1_attack_handling_in_progress = False
        else:
            self.p1_attack_handling_in_progress = False

        # Player 2 attack - Player 1 collision
        if self.walrus2.get_state() == PlayerState.ATTACKING:
            self.p2_attack_point = w2_pos + (self.walrus2.get_facing_dir() * (w2_mass / 3.0))
            pos_diff = w1_pos - self.p2_attack_point
            dist = sqrt((pos_diff[0] * pos_diff[0]) + (pos_diff[1] * pos_diff[1]))
            if not self.p2_attack_handling_in_progress and dist <= PLAYER_HITBOX_SCALE * (w1_mass + w2_mass):
                if dist > 0.0001:
                    self.handle_player_attack(2, pos_diff / dist)
            elif dist > PLAYER_HITBOX_SCALE * (w1_mass + w2_mass):
                self.p2_attack_handling_in_progress = False
        else:
            self.p2_attack_handling_in_progress = False

        # Fish collisions
        var i = 0
        while i < len(self.fish_list):
            var fish_pos = self.fish_list[i].get_position()

            # Fish - Player 1 collision
            pos_diff = w1_pos - fish_pos
            dist = sqrt((pos_diff[0] * pos_diff[0]) + (pos_diff[1] * pos_diff[1]))
            if dist < PLAYER_HITBOX_SCALE * w1_mass + FISH_SIZE and not self.walrus1.is_dead():
                self.handle_fish_collision(1, i)
                break

            # Fish - Player 2 collision
            pos_diff = w2_pos - fish_pos
            dist = sqrt((pos_diff[0] * pos_diff[0]) + (pos_diff[1] * pos_diff[1]))
            if dist < PLAYER_HITBOX_SCALE * w2_mass + FISH_SIZE and not self.walrus2.is_dead():
                self.handle_fish_collision(2, i)
                break

            # Fish - water collision
            if self._tile_dura_at_pos(fish_pos) <= 0.0 and self.fish_list[i].flop_progress_timer <= 0.0:
                self.handle_fish_collision(0, i)
                break

            # Tick update for living fish
            self.fish_list[i].flop(d_sec, self.rng)
            i += 1

    def handle_boundary_collision(mut self, walrus: Int, xpos: Float32):
        if walrus == 1 and xpos <= 0.0:
            if self.walrus2.is_dead():
                self.progression -= 1
                self.round += 1
                self.fish_list.clear()
                self.walrus1.spawn(Vec2f(15.0 * WINDOW_WIDTH / 16.0, WINDOW_HEIGHT / 2.0))
                self.walrus2.spawn(Vec2f(WINDOW_WIDTH / 2.0, WINDOW_HEIGHT / 2.0))

                if self.progression == -1:
                    self.walrus2.handle_power_up(1)
            else:
                var new_vel = self.walrus1.get_vel()
                new_vel[0] *= -1.0
                self.walrus1.set_vel(new_vel)
                self.walrus1.tick_update(COLLISION_KNOCKBACK_TIME)
                self.border_bump = self.sfx_volume * BUMP_VOL_SCALE

        elif walrus == 2 and xpos >= WINDOW_WIDTH:
            if self.walrus1.is_dead():
                self.progression += 1
                self.round += 1
                self.fish_list.clear()
                self.walrus1.spawn(Vec2f(WINDOW_WIDTH / 2.0, WINDOW_HEIGHT / 2.0))
                self.walrus2.spawn(Vec2f(WINDOW_WIDTH / 16.0, WINDOW_HEIGHT / 2.0))

                if self.progression == 1:
                    self.walrus1.handle_power_up(1)
            else:
                var new_vel = self.walrus2.get_vel()
                new_vel[0] *= -1.0
                self.walrus2.set_vel(new_vel)
                self.walrus2.tick_update(COLLISION_KNOCKBACK_TIME)
                self.border_bump = self.sfx_volume * BUMP_VOL_SCALE

        elif walrus == 1 and xpos >= WINDOW_WIDTH:
            var new_vel = self.walrus1.get_vel()
            new_vel[0] *= -1.0
            self.walrus1.set_vel(new_vel)
            self.walrus1.tick_update(COLLISION_KNOCKBACK_TIME)
            self.border_bump = self.sfx_volume * BUMP_VOL_SCALE

        elif walrus == 2 and xpos <= 0.0:
            var new_vel = self.walrus2.get_vel()
            new_vel[0] *= -1.0
            self.walrus2.set_vel(new_vel)
            self.walrus2.tick_update(COLLISION_KNOCKBACK_TIME)
            self.border_bump = self.sfx_volume * BUMP_VOL_SCALE

    def handle_fish_collision(mut self, player: Int, fish_idx: Int):
        var color = Int(self.fish_list[fish_idx].get_color())
        if player == 1:
            self.walrus1.handle_power_up(color)
            self.powerup = self.sfx_volume
        elif player == 2:
            self.walrus2.handle_power_up(color)
            self.powerup = self.sfx_volume

        _ = self.fish_list.pop(fish_idx)

    def handle_player_collision(mut self):
        var w1_vel = self.walrus1.get_vel()
        var w2_vel = self.walrus2.get_vel()
        var w1_pos = self.walrus1.get_pos()
        var w2_pos = self.walrus2.get_pos()
        var w1_mass = self.walrus1.get_mass()
        var w2_mass = self.walrus2.get_mass()

        self.player_collision_point = Vec2f(
            ((w1_pos[0] * w2_mass) + (w2_pos[0] * w1_mass)) / (w1_mass + w2_mass),
            ((w1_pos[1] * w2_mass) + (w2_pos[1] * w1_mass)) / (w1_mass + w2_mass),
        )

        var pos_diff = w1_pos - w2_pos
        var length = sqrt((pos_diff[0] * pos_diff[0]) + (pos_diff[1] * pos_diff[1]))
        if length <= 0.0001:
            return

        var normal = Vec2f(pos_diff[0] / length, pos_diff[1] / length)
        var tangent = Vec2f(-normal[1], normal[0])

        var w1_scalar_norm = (normal[0] * w1_vel[0]) + (normal[1] * w1_vel[1])
        var w2_scalar_norm = (normal[0] * w2_vel[0]) + (normal[1] * w2_vel[1])
        var w1_scalar_tan = (tangent[0] * w1_vel[0]) + (tangent[1] * w1_vel[1])
        var w2_scalar_tan = (tangent[0] * w2_vel[0]) + (tangent[1] * w2_vel[1])

        var w1_new_scalar_norm = (w1_scalar_norm * (w1_mass - w2_mass) + 2.0 * w2_mass * w2_scalar_norm) / (w1_mass + w2_mass)
        var w2_new_scalar_norm = (w2_scalar_norm * (w2_mass - w1_mass) + 2.0 * w1_mass * w1_scalar_norm) / (w1_mass + w2_mass)

        var w1_new_vec_norm = normal * w1_new_scalar_norm
        var w2_new_vec_norm = normal * w2_new_scalar_norm
        var w1_new_vec_tan = tangent * w1_scalar_tan
        var w2_new_vec_tan = tangent * w2_scalar_tan

        self.walrus1.set_vel(w1_new_vec_tan + w1_new_vec_norm)
        self.walrus2.set_vel(w2_new_vec_tan + w2_new_vec_norm)

        self.walrus1.tick_update(COLLISION_KNOCKBACK_TIME)
        self.walrus2.tick_update(COLLISION_KNOCKBACK_TIME)

        var vel_diff = self.walrus1.get_vel() - self.walrus2.get_vel()
        var magnitude = sqrt((vel_diff[0] * vel_diff[0]) + (vel_diff[1] * vel_diff[1]))
        self.player_bump = magnitude * BUMP_VOL_SCALE * (self.sfx_volume / 100.0)

    def handle_player_attack(mut self, attacker: Int, dir: Vec2f):
        if attacker == 2:
            self.p2_attack_handling_in_progress = True
            var attack_charge = self.walrus2.get_attack_charge()
            self.walrus1.set_vel(self.walrus1.get_vel() + (dir * SLASH_ATTACK_POWER * attack_charge))
            self.walrus1.set_stamina(self.walrus1.get_stamina() - ATTACKED_STAMINA_LOST * attack_charge)
            self.player_hit = self.sfx_volume * attack_charge
        elif attacker == 1:
            self.p1_attack_handling_in_progress = True
            var attack_charge = self.walrus1.get_attack_charge()
            self.walrus2.set_vel(self.walrus2.get_vel() + (dir * SLASH_ATTACK_POWER * attack_charge))
            self.walrus2.set_stamina(self.walrus2.get_stamina() - ATTACKED_STAMINA_LOST * attack_charge)
            self.player_hit = self.sfx_volume * attack_charge

    def return_to_menu(mut self):
        self.state = GameStateEnum.MAIN_MENU

    def set_sfx_volume(mut self, mut vol: Float32):
        if vol > SFX_VOLUME_MAX:
            vol = SFX_VOLUME_MAX
        elif vol <= 0.0:
            vol = 0.0
        self.sfx_volume = vol

    def set_music_volume(mut self, mut vol: Float32):
        if vol > MUSIC_VOLUME_MAX:
            vol = MUSIC_VOLUME_MAX
        elif vol <= 0.0:
            vol = 0.0
        self.music_volume = vol

    def get_sfx_volume(self) -> Float32:
        return self.sfx_volume

    def get_music_volume(self) -> Float32:
        return self.music_volume

    def handle_player_death(mut self, walrus: Int):
        if self.walrus2.is_dead() and walrus == 1:
            self.reset_game()

        if walrus == 1:
            if self.walrus2.is_dead():
                self.reset_game()
            else:
                self.walrus1.kill()
                self.walrus2.kills += 1
                if self.progression == 2:
                    self.winner1 = False
                    self.state = GameStateEnum.GAME_OVER_MENU
        elif walrus == 2:
            if self.walrus1.is_dead():
                self.reset_game()
            else:
                self.walrus2.kill()
                self.walrus1.kills += 1
                if self.progression == -2:
                    self.winner1 = True
                    self.state = GameStateEnum.GAME_OVER_MENU

        self.splash = 1.0

    def toggle_pause(mut self):
        if self.state == GameStateEnum.PAUSE_MENU:
            self.state = GameStateEnum.PLAYING
        elif self.state == GameStateEnum.PLAYING:
            self.state = GameStateEnum.PAUSE_MENU

    def reset_game(mut self):
        self.stage.generate_map(self.rng)
        self.state = GameStateEnum.PLAYING
        self.walrus1.spawn(Vec2f(5.0 * WINDOW_WIDTH / 8.0, WINDOW_HEIGHT / 2.0))
        self.walrus2.spawn(Vec2f(3.0 * WINDOW_WIDTH / 8.0, WINDOW_HEIGHT / 2.0))
        if self.progression == -1:
            self.walrus2.handle_power_up(1)
        elif self.progression == 1:
            self.walrus1.handle_power_up(1)

    def handle_options_menu(mut self):
        self.state = GameStateEnum.OPTIONS_MENU

    def handle_stats_menu(mut self):
        self.state = GameStateEnum.STATS_MENU

    def handle_help_menu(mut self):
        self.state = GameStateEnum.HELP_MENU

    def handle_player_select_menu(mut self):
        self.state = GameStateEnum.PLAYER_SELECT_MENU
        self.walrus1.reset_stats()
        self.walrus2.reset_stats()
        self.stage.generate_map(self.rng)
        self.progression = 0
        self.round = 1

    def handle_name_text_submenu(mut self):
        self.state = GameStateEnum.NAME_TEXT_SUBMENU

    def handle_color_select_submenu(mut self):
        self.state = GameStateEnum.COLOR_SELECT_SUBMENU

    def get_state(self) -> GameStateEnum:
        return self.state
    def get_stage_progression(self) -> Int:
        return self.progression
    def get_round(self) -> Int:
        return self.round
