# definitions.mojo
# Contains all game variables for easy tweaking and balancing, and all text strings for easy translation

# --- Window ---
comptime WINDOW_HEIGHT: Float32 = 900.0
comptime WINDOW_WIDTH: Float32  = 1200.0
comptime APP_TITLE: String = "Walrus Wars"

# --- Collision Variables ---
comptime SLASH_ATTACK_POWER: Float32       = 100.0
comptime COLLISION_KNOCKBACK_TIME: Float32 = 0.04

# Comes from removing the drawing of mass*20 and hitbox of mass*6.5 (6.5 / 20 == 0.325)
comptime PLAYER_HITBOX_SCALE: Float32 = 0.325

# --- Basic Movement Forces ---
comptime DECELERATE_STRENGTH: Float32 = 20.0
comptime ACCELERATE_STRENGTH: Float32 = 500.0

comptime DEAD_MOVEMENT_SCALEDOWN: Float32          = 0.0
comptime RESTING_MOVEMENT_SCALEDOWN: Float32       = 0.2
comptime RAISING_TUSKS_MOVEMENT_SCALEDOWN: Float32 = 0.0
comptime ATTACKING_MOVEMENT_SCALEDOWN: Float32     = 0.2

# --- Bot ---
comptime NUM_OF_RAYS_CAST: Int = 16
comptime PI: Float32 = 3.14159265

# --- Powerups ---
comptime FISH_SPEED_BOOST: Float32 = 0.1
comptime FISH_MASS_BOOST: Float32  = 8.0

# --- Stamina ---
comptime MAX_STAMINA: Float32               = 100.0
comptime STAMINA_THRESHOLD: Float32         = MAX_STAMINA / 4.0
comptime NORMAL_STAMINA_REGEN_RATE: Float32 = 10.0
comptime RESTING_STAMINA_REGEN_RATE: Float32 = 20.0
comptime FISH_STAMINA_GAINED: Float32       = 20.0
comptime ATTACK_STAMINA_COST: Float32       = 20.0
comptime ATTACKED_STAMINA_LOST: Float32     = 15.0
comptime MOVEMENT_STAMINA_COST_SCALE: Float32 = 30.0
comptime MAX_ATTACK_CHARGE: Float32         = 5.0

comptime INIT_MASS: Float32 = 80.0

# --- Stage ---
comptime ICE_BLOCKS_WIDTH: Int    = 40
comptime ICE_BLOCKS_HEIGHT: Int   = 30
comptime ICE_BLOCKS_SIZE_X: Float32 = WINDOW_WIDTH / Float32(ICE_BLOCKS_WIDTH)
comptime ICE_BLOCKS_SIZE_Y: Float32 = WINDOW_HEIGHT / Float32(ICE_BLOCKS_HEIGHT)

# --- Fish ---
comptime FISH_SIZE: Float32     = 30.0
comptime MAX_NUM_OF_FISH: Int   = 8

# --- Animations ---
comptime ATTACK_RELEASE_TIMER: Float32  = 0.30
comptime ATTACK_DURATION_TIMER: Float32 = 0.60

# --- Text ---
comptime UI_TEXT_SIZE: Int = 100

# --- Strings ---
comptime GO_RIGHT: String             = "GO ->"
comptime GO_LEFT: String              = "<- GO"
comptime OPTIONS_TITLE_STRING: String = "OPTIONS:"
comptime SFX_VOLUME_STRING: String    = "SFX Volume: "
comptime MUSIC_VOLUME_STRING: String  = "Music Volume: "
comptime PLAY_STRING: String          = "Play"
comptime HELP_STRING: String          = "Help"
comptime OPTIONS_STRING: String       = "Options"
comptime QUIT_STRING: String          = "Quit"
comptime REPLAY: String               = "Play Again"
comptime STATS_TEXT: String           = "Stats"
comptime MAIN_MENU: String            = "Return to Main Menu"
comptime P1: String                   = "Player 1"
comptime P2: String                   = "Player 2"
comptime BOT: String                  = "Bot"
comptime WON: String                  = " Won!"
comptime KILLS: String                = "Kills: "
comptime DEATHS: String               = "Deaths: "
comptime POWERUPS: String             = "Powerups: "
comptime SLASH_ATTACKS: String        = "Slash Attacks: "
comptime DIST: String                 = "Distance (m): "
comptime PAUSED: String               = "Paused"
comptime RESUME: String               = "Resume"
comptime BACKGROUND_A: String         = "Throughout the Arctic, sea ice deteriorates at astonishing rates.\n Global warming poses the biggest threat to walruses in the Arctic\n - their habitat is vanishing!\n\nTwo walruses, "
comptime BACKGROUND_B: String         = " must fight over scarce land\nand food to claim a suitable location for their families... they must\nforce their competitors off the ice!"
comptime CONTROL_INSTRUCTIONS: String = "Player 1 movement = WASD, Player 2 movement = Arrow Keys\n Player 1 attack = LSHIFT, Player 2 attack = RSHIFT"
comptime GAME_RULES: String           = "Being efficient with your actions to maintain stamina is crucial!\nSlash your opponent to deplete their stamina & eat fish \nto recover your own stamina:\n - Red increases movement speed, Green increases flubber mass\nProgress to the next stage to continue! \nThe first walrus to reach the end wins!"
comptime DEFAULT_NAME_1: String       = "Wally"
comptime DEFAULT_NAME_2: String       = "Wahlberg"
comptime MAX_INPUT_SIZE: Int                 = 7

# --- Volume ---
comptime SFX_VOLUME_BASE: Float32   = 50.0
comptime MUSIC_VOLUME_BASE: Float32 = 50.0
comptime SFX_VOLUME_MAX: Float32    = 100.0
comptime MUSIC_VOLUME_MAX: Float32  = 100.0
comptime VOLUME_BAR_WIDTH: Float32  = 200.0
comptime BUMP_VOL_SCALE: Float32    = 0.2
