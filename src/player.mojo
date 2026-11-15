from std.math import sqrt
from gammaraylib import Vec2f, Vec4f
from definitions import *


struct PlayerState(Equatable, ImplicitlyCopyable, Movable):
    var value: Int

    comptime IDLE          = Self(0)
    comptime NORMAL        = Self(1)
    comptime RUNNING       = Self(2)
    comptime RAISING_TUSKS = Self(3)
    comptime ATTACKING     = Self(4)
    comptime RESTING       = Self(5)
    comptime DEAD          = Self(6)

    def __init__(out self, value: Int):
        self.value = value
    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value
    def __ne__(self, other: Self) -> Bool:
        return self.value != other.value


struct Player(Copyable, Movable):
    # Public stats
    var kills: Int
    var deaths: Int
    var powerups_collected: Int
    var slash_attack_num: Int
    var distance_travelled: Float32

    # Internal player state
    var name: String
    var pos: Vec2f
    var vel: Vec2f
    var facing_dir: Vec2f
    var attack_collision_pt: Vec2f
    var color: Vec4f
    var state: PlayerState
    var mass: Float32
    var stamina: Float32
    var speed_boost: Float32
    var attack_charge: Float32
    var attack_release_timer: Float32
    var attack_duration_timer: Float32

    def __init__(out self):
        self.kills = 0
        self.deaths = 0
        self.powerups_collected = 0
        self.slash_attack_num = 0
        self.distance_travelled = 0.0

        self.name = ""
        self.pos = Vec2f(0.0, 0.0)
        self.vel = Vec2f(0.0, 0.0)
        self.facing_dir = Vec2f(0.0, 1.0)
        self.attack_collision_pt = Vec2f(0.0, 0.0)
        self.color = Vec4f(1.0, 1.0, 1.0, 1.0)
        self.state = PlayerState.NORMAL
        self.mass = INIT_MASS
        self.stamina = MAX_STAMINA
        self.speed_boost = 1.0
        self.attack_charge = 0.0
        self.attack_release_timer = 0.0
        self.attack_duration_timer = 0.0

    def spawn(mut self, spawn_pos: Vec2f):
        self.mass = INIT_MASS
        self.stamina = MAX_STAMINA
        self.pos = spawn_pos
        self.vel = Vec2f(0.0, 0.0)
        self.state = PlayerState.NORMAL
        self.speed_boost = 1.0
        self.facing_dir = Vec2f(0.0, 1.0)
        self.attack_charge = 0.0
        self.attack_release_timer = 0.0
        self.attack_duration_timer = 0.0

    def tick_update(mut self, d_sec: Float32):
        var tmp_x = self.pos[0]
        var tmp_y = self.pos[1]

        # Update movement
        self.pos = self.pos + (self.vel * d_sec)
        self.distance_travelled += abs(tmp_x - self.pos[0]) + abs(tmp_y - self.pos[1])

        # Regenerate stamina
        if self.state == PlayerState.RESTING:
            self.stamina += RESTING_STAMINA_REGEN_RATE * d_sec
            if self.stamina > STAMINA_THRESHOLD:
                self.state = PlayerState.NORMAL
        else:
            self.stamina += NORMAL_STAMINA_REGEN_RATE * d_sec

        # Cap stamina
        if self.stamina > MAX_STAMINA:
            self.stamina = MAX_STAMINA

            # Check if not moving and set to idle
            var speed = sqrt((self.vel[0] * self.vel[0]) + (self.vel[1] * self.vel[1]))
            if self.state == PlayerState.NORMAL and speed < 0.1:
                self.state = PlayerState.IDLE
        elif self.stamina < 0.0:
            self.stamina = 0.0

        # If raising tusks, decrement attack release timer
        if self.attack_release_timer > 0.0:
            self.attack_release_timer -= d_sec
        elif self.state == PlayerState.RAISING_TUSKS and self.attack_release_timer <= 0.0:
            self.attack_release_timer = 0.0
            self.slash()

        # If attacking, decrement attack duration timer
        if self.attack_duration_timer > 0.0:
            self.attack_duration_timer -= d_sec
        elif self.state == PlayerState.ATTACKING and self.attack_duration_timer <= 0.0:
            self.attack_duration_timer = 0.0
            self.attack_charge = 0.0
            self.state = PlayerState.NORMAL

    def apply_passive_force(mut self, d_sec: Float32):
        var resting_resistance: Float32 = 2.0 if self.state == PlayerState.RESTING else 1.0
        var vx = self.vel[0]
        var vy = self.vel[1]

        if vx > 0.0:
            vx -= d_sec * resting_resistance * DECELERATE_STRENGTH
        elif vx < 0.0:
            vx += d_sec * resting_resistance * DECELERATE_STRENGTH

        if vy > 0.0:
            vy -= d_sec * resting_resistance * DECELERATE_STRENGTH
        elif vy < 0.0:
            vy += d_sec * resting_resistance * DECELERATE_STRENGTH

        self.vel = Vec2f(vx, vy)

    def apply_active_force(mut self, mut force_dir: Vec2f, d_sec: Float32):
        if force_dir[0] != 0.0 or force_dir[1] != 0.0:
            self.facing_dir = force_dir

        if self.state == PlayerState.DEAD:
            force_dir = force_dir * DEAD_MOVEMENT_SCALEDOWN
        elif self.state == PlayerState.RESTING:
            force_dir = force_dir * RESTING_MOVEMENT_SCALEDOWN
        elif self.state == PlayerState.RAISING_TUSKS:
            force_dir = force_dir * RAISING_TUSKS_MOVEMENT_SCALEDOWN
        elif self.state == PlayerState.ATTACKING:
            force_dir = force_dir * ATTACKING_MOVEMENT_SCALEDOWN
        elif self.state == PlayerState.IDLE:
            self.facing_dir = Vec2f(0.0, 1.0)
            if force_dir[0] != 0.0 or force_dir[1] != 0.0:
                self.state = PlayerState.RUNNING
        else:
            if force_dir[0] == 0.0 and force_dir[1] == 0.0:
                self.state = PlayerState.NORMAL
            else:
                self.state = PlayerState.RUNNING

        var force_mag = sqrt((force_dir[0] * force_dir[0]) + (force_dir[1] * force_dir[1]))
        self.stamina -= force_mag * d_sec * MOVEMENT_STAMINA_COST_SCALE
        force_dir = force_dir * self.speed_boost
        self.vel = self.vel + (force_dir * d_sec * ACCELERATE_STRENGTH)

        if self.stamina < 0.0:
            self.state = PlayerState.RESTING
            self.attack_charge = 0.0

    def handle_power_up(mut self, powerup: Int):
        self.powerups_collected += 1
        self.stamina += FISH_STAMINA_GAINED
        if powerup == 0:
            self.speed_boost += FISH_SPEED_BOOST
        elif powerup == 1:
            self.mass += FISH_MASS_BOOST

    def raise_tusks(mut self, d_sec: Float32):
        self.state = PlayerState.RAISING_TUSKS
        if self.attack_charge < 1.0:
            self.attack_charge = 1.0
        self.attack_charge += d_sec
        if self.attack_charge > MAX_ATTACK_CHARGE:
            self.attack_charge = MAX_ATTACK_CHARGE
        self.attack_release_timer = ATTACK_RELEASE_TIMER

    def slash(mut self):
        self.slash_attack_num += 1
        print("SLASH:", self.attack_charge)
        self.stamina -= ATTACK_STAMINA_COST
        self.attack_duration_timer = ATTACK_DURATION_TIMER
        self.state = PlayerState.ATTACKING

    def kill(mut self):
        self.state = PlayerState.DEAD
        self.deaths += 1

    def is_dead(self) -> Bool:
        return self.state == PlayerState.DEAD

    # --- Setters ---
    def set_vel(mut self, new_vel: Vec2f):
        self.vel = new_vel
    def set_stamina(mut self, new_stamina: Float32):
        self.stamina = new_stamina
    def set_color(mut self, new_color: Vec4f):
        self.color = new_color
    def set_name(mut self, new_name: String):
        self.name = new_name
    def reset_stats(mut self):
        self.kills = 0
        self.deaths = 0
        self.powerups_collected = 0
        self.slash_attack_num = 0
        self.distance_travelled = 0.0
    # --- Getters ---
    def get_state(self) -> PlayerState:
        return self.state
    def get_name(self) -> String:
        return self.name
    def get_color(self) -> Vec4f:
        return self.color
    def get_pos(self) -> Vec2f:
        return self.pos
    def get_vel(self) -> Vec2f:
        return self.vel
    def get_facing_dir(self) -> Vec2f:
        return self.facing_dir
    def get_attack_charge(self) -> Float32:
        return self.attack_charge
    def get_mass(self) -> Float32:
        return self.mass
    def get_stamina(self) -> Float32:
        return self.stamina
