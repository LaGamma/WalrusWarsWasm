from std.collections import List
from std.math import sin
from gammaraylib import *
from definitions import *
from animation import Animation
from botcontroller import BotController
from gamelogic import GameLogic, GameStateEnum
from player import PlayerState, Player
from playercontroller import PlayerController
from soundmanager import MusicTrack, SFX, SoundManager
from watershader import WaterShader
from rng import GameRng
from netclient import NetClient

comptime COLOR_1 = Vec4f(1.0, 1.0, 1.0, 1.0)
comptime COLOR_2 = Vec4f(155.0 / 255.0, 155.0 / 255.0, 155.0 / 255.0, 1.0)
comptime COLOR_3 = Vec4f(1.0, 155.0 / 255.0, 155.0 / 255.0, 1.0)
comptime COLOR_4 = Vec4f(155.0 / 255.0, 1.0, 155.0 / 255.0, 1.0)
comptime COLOR_5 = Vec4f(155.0 / 255.0, 155.0 / 255.0, 1.0, 1.0)

comptime UI_FONT_SCALE: Float32 = 1.38

struct CameraView(Movable):
    var main_menu_selection: String
    var options_menu_selection: String
    var game_over_menu_selection: String
    var player1_menu_selection: String
    var pause_menu_selection: String
    var color_selection: String

    var color_selector: Bool
    var entering_name_text: Bool
    var player1_or_bot: Int  # -1 is bot, 1 is player
    var player2_or_bot: Int  # -1 is bot, 1 is player

    # Controllers
    var player_controller: PlayerController
    var bot1_controller: BotController
    var bot2_controller: BotController

    # Sound & Animations
    var sound_manager: SoundManager
    var walrus1_animation: Animation
    var walrus2_animation: Animation
    var round_counter_10_anim: Animation
    var round_counter_20_anim: Animation
    var walrus_splash_anim: Animation
    var water_animation: Animation
    var fish_animation_list: List[Animation]

    # Textures
    var sprite_map_walrus: Texture2D
    var sprite_map_fish: Texture2D
    var menu_background: Texture2D
    var stage_progression: Texture2D
    var stage_progression_active: Texture2D
    var player_portrait: Texture2D
    var player1_select: Texture2D
    var player2_select: Texture2D
    var player_portrait_frame: Texture2D
    var name_frame: Texture2D
    var color_icon: Texture2D
    var player_neutral_select: Texture2D
    var round_counter_10: Texture2D
    var round_counter_20: Texture2D
    var round_counter: Texture2D
    var walrus_splash: Texture2D
    var water: Texture2D

    # Player names
    var walrus1_name_str: String
    var walrus2_name_str: String
    var last_edited_slot: Int

    # Screen shake & timers
    var screenshake_magnitude: Float32
    var screenshake_timer: Float32
    var splash_timer: Float32
    var debug_mode: Bool

    var water_shader: WaterShader

    var rng: GameRng

    var net: NetClient
    var server_url: String

    def __init__(out self, mut rl: Raylib) raises:
        self.main_menu_selection = "P"
        self.options_menu_selection = "S"
        self.game_over_menu_selection = "P"
        self.player1_menu_selection = "P"
        self.pause_menu_selection = "R"
        self.color_selection = "1"

        self.color_selector = False
        self.entering_name_text = False
        self.player1_or_bot = -1
        self.player2_or_bot = -1

        self.player_controller = PlayerController()
        self.bot1_controller = BotController()
        self.bot2_controller = BotController()

        self.sound_manager = SoundManager(rl)

        # Load textures with fallback placeholders if files are missing
        self.sprite_map_walrus = Self._load_tex(rl, "assets/images/WalrusSS.png")
        self.sprite_map_fish = Self._load_tex(rl, "assets/images/FishSS.png")
        self.menu_background = Self._load_tex(rl, "assets/images/menu_title.png")
        self.stage_progression = Self._load_tex(rl, "assets/images/MinimapPlatform.png")
        self.stage_progression_active = Self._load_tex(rl, "assets/images/MinimapPlatformActive.png")
        self.player1_select = Self._load_tex(rl, "assets/images/player1Select.png")
        self.player2_select = Self._load_tex(rl, "assets/images/player2Select.png")
        self.player_neutral_select = Self._load_tex(rl, "assets/images/playerNeutralSelect.png")
        self.player_portrait_frame = Self._load_tex(rl, "assets/images/playerPortraitFrame.png")
        self.player_portrait = Self._load_tex(rl, "assets/images/playerPortrait.png")
        self.name_frame = Self._load_tex(rl, "assets/images/nameFrame.png")
        self.color_icon = Self._load_tex(rl, "assets/images/colorIcon.png")
        self.round_counter = Self._load_tex(rl, "assets/images/roundCounter.png")
        self.round_counter_10 = Self._load_tex(rl, "assets/images/roundCounter10.png")
        self.round_counter_20 = Self._load_tex(rl, "assets/images/roundCounter20.png")
        self.walrus_splash = Self._load_tex(rl, "assets/images/walrusSplash.png")
        self.water = Self._load_tex(rl, "assets/images/water_animation.png")

        self.walrus1_animation = Animation()
        self.walrus2_animation = Animation()
        self.round_counter_10_anim = Animation()
        self.round_counter_20_anim = Animation()
        self.walrus_splash_anim = Animation()
        self.water_animation = Animation()

        self.walrus1_animation.init(self.sprite_map_walrus, 3, 11, 0.15)
        self.walrus2_animation.init(self.sprite_map_walrus, 3, 11, 0.15)
        self.round_counter_10_anim.init(self.round_counter_10, 3, 1, 0.3)
        self.round_counter_20_anim.init(self.round_counter_20, 3, 1, 0.3)
        self.walrus_splash_anim.init(self.walrus_splash, 3, 1, 0.3)
        self.water_animation.init(self.water, 3, 1, 0.9)
        self.water_shader = WaterShader(rl.gl)

        self.fish_animation_list = List[Animation]()
        for _ in range(MAX_NUM_OF_FISH):
            var anim = Animation()
            anim.init(self.sprite_map_fish, 2, 2, 0.2)
            self.fish_animation_list.append(anim)

        self.walrus1_name_str = String(DEFAULT_NAME_1)
        self.walrus2_name_str = String(DEFAULT_NAME_2)
        self.last_edited_slot = 1

        self.screenshake_magnitude = 0.0
        self.screenshake_timer = 0.0
        self.splash_timer = 0.0
        self.debug_mode = False

        self.sound_manager.play_music(rl, MusicTrack.TITLE)

        self.rng = GameRng(12345)

        self.net = NetClient()
        self.server_url = "ws://127.0.0.1:8765"

    @staticmethod
    def _load_tex(mut rl: Raylib, path: String) raises -> Texture2D:
        try:
            return rl.load_texture(path)
        except e:
            print("TEX FAIL:", path, "->", e)
            return rl.gen_texture_checked(64, 64, 8, 8)

    @staticmethod
    def _draw_tex_rect(
        mut rl: Raylib,
        tex: Texture2D,
        src: Rectangle,
        dst: Rectangle,
        tint: Vec4f = Vec4f(1.0, 1.0, 1.0, 1.0),
    ) raises:
        rl.draw_texture_pro(tex, src, dst, Vec2f(0.0, 0.0), 0.0, tint)

    def draw(mut self, mut rl: Raylib, mut logic: GameLogic) raises:
        var state = logic.get_state()
        rl.begin_drawing()

        if state == GameStateEnum.MAIN_MENU:
            self.draw_main_menu(rl, logic)
            self.sound_manager.set_music_volume(logic.get_music_volume())
        elif state == GameStateEnum.PAUSE_MENU:
            self.draw_game(rl, logic)
            self.draw_pause_menu(rl, logic)
            self.sound_manager.set_music_volume(logic.get_music_volume() * 0.5)
        elif state == GameStateEnum.PLAYING:
            self.draw_game(rl, logic)
            self.sound_manager.set_music_volume(logic.get_music_volume())
        elif state == GameStateEnum.GAME_OVER_MENU:
            self.draw_game_over_menu(rl, logic)
            self.sound_manager.set_music_volume(logic.get_music_volume())
        elif state == GameStateEnum.OPTIONS_MENU:
            self.draw_options_menu(rl, logic)
            self.sound_manager.set_music_volume(logic.get_music_volume())
        elif state == GameStateEnum.STATS_MENU:
            self.draw_stats_menu(rl, logic)
        elif (
            state == GameStateEnum.PLAYER_SELECT_MENU
            or state == GameStateEnum.COLOR_SELECT_SUBMENU
            or state == GameStateEnum.NAME_TEXT_SUBMENU
        ):
            self.draw_player_select_menu(rl, logic)
        elif state == GameStateEnum.HELP_MENU:
            self.draw_help_menu(rl, logic)

        rl.end_drawing()

    def _text(self, mut rl: Raylib, text: String, x: Float32, y: Float32, size: Float32, color: Vec4f) raises:
        rl.draw_text(text, x, y, size * UI_FONT_SCALE, color)

    def draw_main_menu(mut self, mut rl: Raylib, logic: GameLogic) raises:
        rl.clear_background(Vec4f(50.0 / 255.0, 50.0 / 255.0, 50.0 / 255.0, 1.0))

        # Draw water background
        Self._draw_tex_rect(
            rl,
            self.water,
            self.water_animation.uv_rect,
            Rectangle(0.0, 0.0, WINDOW_WIDTH, WINDOW_HEIGHT),
        )

        # Main menu title overlay
        Self._draw_tex_rect(
            rl,
            self.menu_background,
            Rectangle(0.0, 0.0, Float32(self.menu_background.width), Float32(self.menu_background.height)),
            Rectangle(0.0, 0.0, WINDOW_WIDTH, WINDOW_HEIGHT),
        )

        var white = Vec4f(1.0, 1.0, 1.0, 1.0)
        var black = Vec4f(0.0, 0.0, 0.0, 1.0)

        var play_col = black if self.main_menu_selection == "P" else white
        var help_col = black if self.main_menu_selection == "H" else white
        var opt_col = black if self.main_menu_selection == "O" else white

        var play_str = String(PLAY_STRING)
        var help_str = String(HELP_STRING)
        var opt_str = String(OPTIONS_STRING)

        self._text(rl, play_str, (WINDOW_WIDTH - rl.measure_text(play_str, 60.0)) * 0.5, 325.0 * WINDOW_HEIGHT / 600.0, 60.0, play_col)
        self._text(rl, help_str, (WINDOW_WIDTH - rl.measure_text(help_str, 60.0)) * 0.5, 2.0 * WINDOW_HEIGHT / 3.0, 60.0, help_col)
        self._text(rl, opt_str, (WINDOW_WIDTH - rl.measure_text(opt_str, 60.0)) * 0.5, 475.0 * WINDOW_HEIGHT / 600.0, 60.0, opt_col)


    def draw_pause_menu(self, mut rl: Raylib, logic: GameLogic) raises:
        # Semi-transparent yellow overlay
        rl.draw_rectangle(0.0, 0.0, WINDOW_WIDTH, WINDOW_HEIGHT, Vec4f(1.0, 1.0, 0.0, 0.5))

        var gray = Vec4f(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0, 1.0)
        var white = Vec4f(1.0, 1.0, 1.0, 1.0)
        var black = Vec4f(0.0, 0.0, 0.0, 1.0)

        self._text(rl, String(PAUSED), WINDOW_WIDTH / 2.0 - 100.0, WINDOW_HEIGHT / 4.0, 72.0, gray)

        var resume_col = black if self.pause_menu_selection == "R" else white
        var quit_col = black if self.pause_menu_selection == "Q" else white

        self._text(rl, String(RESUME), WINDOW_WIDTH / 2.0 - 110.0, WINDOW_HEIGHT / 2.0 + 100.0, 64.0, resume_col)
        self._text(rl, String(QUIT_STRING), WINDOW_WIDTH / 2.0 - 50.0, WINDOW_HEIGHT / 2.0 + 170.0, 64.0, quit_col)

    def draw_help_menu(mut self, mut rl: Raylib, logic: GameLogic) raises:
        rl.clear_background(Vec4f(50.0 / 255.0, 50.0 / 255.0, 50.0 / 255.0, 1.0))

        var story = (
            String(BACKGROUND_A)
            + logic.walrus1.get_name()
            + " & "
            + logic.walrus2.get_name()
            + String(BACKGROUND_B)
        )
        self._text(rl, story, WINDOW_WIDTH / 20.0, 25.0, 26.0, Vec4f(1.0, 1.0, 1.0, 1.0))
        self._text(rl, String(CONTROL_INSTRUCTIONS), WINDOW_WIDTH / 20.0, 330.0, 26.0, Vec4f(0.3, 0.6, 1.0, 1.0))
        self._text(rl, String(GAME_RULES), WINDOW_WIDTH / 20.0, 465.0, 26.0, Vec4f(1.0, 1.0, 0.0, 1.0))
        self._text(rl, String(MAIN_MENU), WINDOW_WIDTH / 2.0 - 300.0, 775.0, 52.0, Vec4f(0.0, 0.0, 0.0, 1.0))


        # P1 preview sprite & baby walruses
        var p1_x = WINDOW_WIDTH * 17.5 / 20.0
        var p1_y = WINDOW_HEIGHT / 6.0 + 30.0
        self.walrus1_animation.set_current_sprite(1, 9, False)
        Self._draw_tex_rect(
            rl,
            self.sprite_map_walrus,
            self.walrus1_animation.uv_rect,
            Rectangle(p1_x, p1_y, 80.0, 80.0),
            logic.walrus1.get_color(),
        )
        self.walrus1_animation.set_current_sprite(2, 3, False)
        Self._draw_tex_rect(
            rl,
            self.sprite_map_walrus,
            self.walrus1_animation.uv_rect,
            Rectangle(p1_x + 60.0, p1_y + 35.0, 40.0, 40.0),
            logic.walrus1.get_color(),
        )
        Self._draw_tex_rect(
            rl,
            self.sprite_map_walrus,
            self.walrus1_animation.uv_rect,
            Rectangle(p1_x + 50.0, p1_y + 45.0, 40.0, 40.0),
            logic.walrus1.get_color(),
        )

        # P2 preview sprite & baby walruses
        var p2_x = WINDOW_WIDTH * 15.5 / 20.0
        var p2_y = WINDOW_HEIGHT / 6.0 + 30.0
        self.walrus2_animation.set_current_sprite(1, 9, True)
        Self._draw_tex_rect(
            rl,
            self.sprite_map_walrus,
            self.walrus2_animation.uv_rect,
            Rectangle(p2_x, p2_y, 80.0, 80.0),
            logic.walrus2.get_color(),
        )
        self.walrus2_animation.set_current_sprite(2, 3, True)
        Self._draw_tex_rect(
            rl,
            self.sprite_map_walrus,
            self.walrus2_animation.uv_rect,
            Rectangle(p2_x - 20.0, p2_y + 35.0, 40.0, 40.0),
            logic.walrus2.get_color(),
        )
        Self._draw_tex_rect(
            rl,
            self.sprite_map_walrus,
            self.walrus2_animation.uv_rect,
            Rectangle(p2_x - 10.0, p2_y + 45.0, 40.0, 40.0),
            logic.walrus2.get_color(),
        )

        # Fish powerup previews
        var fish_anim = Animation()
        fish_anim.init(self.sprite_map_fish, 2, 2, 0.3)
        var fx = WINDOW_WIDTH * 11.0 / 16.0
        var fy = WINDOW_HEIGHT * 12.0 / 16.0
        fish_anim.set_current_sprite(1, 0, False)
        Self._draw_tex_rect(rl, self.sprite_map_fish, fish_anim.uv_rect, Rectangle(fx, fy, 80.0, 80.0))
        fish_anim.set_current_sprite(1, 1, False)
        Self._draw_tex_rect(rl, self.sprite_map_fish, fish_anim.uv_rect, Rectangle(fx + 100.0, fy, 80.0, 80.0))

    def draw_options_menu(self, mut rl: Raylib, logic: GameLogic) raises:
        rl.clear_background(Vec4f(50.0 / 255.0, 50.0 / 255.0, 50.0 / 255.0, 1.0))

        var white = Vec4f(1.0, 1.0, 1.0, 1.0)
        var cyan = Vec4f(0.0, 1.0, 1.0, 1.0)
        var black = Vec4f(0.0, 0.0, 0.0, 1.0)

        self._text(rl, String(OPTIONS_TITLE_STRING), WINDOW_WIDTH / 2.0 - 200.0, 25.0, 80.0, white)

        var sfx_y = WINDOW_HEIGHT / 4.0
        var mus_y = sfx_y + 120.0
        var quit_y = mus_y + 150.0
        var bar_x = (WINDOW_WIDTH / 10.0) + 460.0

        # SFX slider bar + knob
        rl.draw_rectangle(bar_x, sfx_y + 10.0, VOLUME_BAR_WIDTH, 24.0, black)
        var sfx_knob_x = bar_x + (logic.get_sfx_volume() / SFX_VOLUME_MAX) * VOLUME_BAR_WIDTH
        rl.draw_circle(sfx_knob_x, sfx_y + 22.0, 16.0, cyan)

        # Music slider bar + knob
        rl.draw_rectangle(bar_x, mus_y + 10.0, VOLUME_BAR_WIDTH, 24.0, black)
        var mus_knob_x = bar_x + (logic.get_music_volume() / MUSIC_VOLUME_MAX) * VOLUME_BAR_WIDTH
        rl.draw_circle(mus_knob_x, mus_y + 22.0, 16.0, cyan)

        var sfx_col = cyan if self.options_menu_selection == "S" else white
        var mus_col = cyan if self.options_menu_selection == "M" else white
        var quit_col = cyan if self.options_menu_selection == "Q" else white

        self._text(rl, String(SFX_VOLUME_STRING), WINDOW_WIDTH / 10.0, sfx_y, 48.0, sfx_col)
        self._text(rl, String(MUSIC_VOLUME_STRING), WINDOW_WIDTH / 10.0, mus_y, 48.0, mus_col)
        self._text(rl, String(QUIT_STRING), WINDOW_WIDTH / 10.0, quit_y, 48.0, quit_col)

    def draw_player_select_menu(self, mut rl: Raylib, mut logic: GameLogic) raises:
        rl.clear_background(Vec4f(50.0 / 255.0, 50.0 / 255.0, 50.0 / 255.0, 1.0))

        var white = Vec4f(1.0, 1.0, 1.0, 1.0)
        var cyan = Vec4f(0.0, 1.0, 1.0, 1.0)
        var red = Vec4f(1.0, 0.0, 0.0, 1.0)
        var blue = Vec4f(0.2, 0.4, 1.0, 1.0)

        var frame_w = 325.0 * WINDOW_WIDTH / 800.0
        var frame_h = 425.0 * WINDOW_HEIGHT / 800.0
        var p1_fx = 50.0 * WINDOW_WIDTH / 800.0
        var p1_fy = 60.0 * WINDOW_HEIGHT / 600.0
        var p2_fx = p1_fx + frame_w + (50.0 * WINDOW_WIDTH / 800.0)
        var p2_fy = p1_fy

        var frame_src = Rectangle(
            0.0, 0.0, Float32(self.player_portrait_frame.width), Float32(self.player_portrait_frame.height)
        )
        var port_src = Rectangle(
            0.0, 0.0, Float32(self.player_portrait.width), Float32(self.player_portrait.height)
        )

        # Portrait frames
        Self._draw_tex_rect(rl, self.player_portrait_frame, frame_src, Rectangle(p1_fx, p1_fy, frame_w, frame_h))
        Self._draw_tex_rect(rl, self.player_portrait_frame, frame_src, Rectangle(p2_fx, p2_fy, frame_w, frame_h))

        # Bot or Player labels
        if self.player1_or_bot == 1:
            self._text(rl, String(P1), p1_fx + 150.0, p1_fy - 60.0, 48.0, red)
        else:
            self._text(rl, String(BOT), p1_fx + 200.0, p1_fy - 60.0, 48.0, white)

        if self.player2_or_bot == 1:
            self._text(rl, String(P2), p2_fx + 150.0, p2_fy - 60.0, 48.0, blue)
        else:
            self._text(rl, String(BOT), p2_fx + 200.0, p2_fy - 60.0, 48.0, white)

        # Apply active color selection before drawing portraits
        if self.color_selector:
            var chosen = COLOR_1
            if self.color_selection == "2":
                chosen = COLOR_2
            elif self.color_selection == "3":
                chosen = COLOR_3
            elif self.color_selection == "4":
                chosen = COLOR_4
            elif self.color_selection == "5":
                chosen = COLOR_5

            if self.player1_menu_selection == "1":
                logic.walrus1.set_color(chosen)
            elif self.player1_menu_selection == "2":
                logic.walrus2.set_color(chosen)

        # Portraits
        Self._draw_tex_rect(
            rl, self.player_portrait, port_src, Rectangle(p1_fx, p1_fy, frame_w, frame_h), logic.walrus1.get_color()
        )
        Self._draw_tex_rect(
            rl, self.player_portrait, port_src, Rectangle(p2_fx, p2_fy, frame_w, frame_h), logic.walrus2.get_color()
        )

        # Name boxes
        var n1_bg_x = p1_fx + 115.0
        var n1_bg_y = p1_fy + 320.0
        var n2_bg_x = p2_fx + 115.0
        var n2_bg_y = p2_fy + 320.0

        var border1_col = red if (self.entering_name_text and self.player1_menu_selection == "1") else Vec4f(0.78, 0.78, 0.78, 1.0)
        var border2_col = red if (self.entering_name_text and self.player1_menu_selection != "1") else Vec4f(0.78, 0.78, 0.78, 1.0)
        var box_gray = Vec4f(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0, 1.0)

        rl.draw_rectangle(p1_fx + 100.0, p1_fy + 310.0, 330.0, 90.0, border1_col)
        rl.draw_rectangle(p2_fx + 100.0, p2_fy + 310.0, 330.0, 90.0, border2_col)
        rl.draw_rectangle(n1_bg_x, n1_bg_y, 300.0, 60.0, box_gray)
        rl.draw_rectangle(n2_bg_x, n2_bg_y, 300.0, 60.0, box_gray)

        var disp_name1 = self.walrus1_name_str if (self.entering_name_text and self.player1_menu_selection == "1") else logic.walrus1.get_name()
        var disp_name2 = self.walrus2_name_str if (self.entering_name_text and self.player1_menu_selection != "1") else logic.walrus2.get_name()

        var name_box_sz: Float32 = 68.0
        var name_y1 = n1_bg_y + (60.0 - name_box_sz * UI_FONT_SCALE) * 0.5 - 2.0
        var name_y2 = n2_bg_y + (60.0 - name_box_sz * UI_FONT_SCALE) * 0.5 - 2.0
        self._text(rl, disp_name1, n1_bg_x + 12.0, name_y1, name_box_sz, white)
        self._text(rl, disp_name2, n2_bg_x + 12.0, name_y2, name_box_sz, white)

        # Color icons
        if self.color_selector:
            var base_x = (n1_bg_x - 25.0) if self.player1_menu_selection == "1" else (n2_bg_x - 25.0)
            var base_y = (n1_bg_y + 65.0) if self.player1_menu_selection == "1" else (n2_bg_y + 65.0)
            var ci_src = Rectangle(0.0, 0.0, Float32(self.color_icon.width), Float32(self.color_icon.height))

            Self._draw_tex_rect(rl, self.color_icon, ci_src, Rectangle(base_x, base_y, 60.0, 60.0), COLOR_1)
            Self._draw_tex_rect(rl, self.color_icon, ci_src, Rectangle(base_x + 60.0, base_y, 60.0, 60.0), COLOR_2)
            Self._draw_tex_rect(rl, self.color_icon, ci_src, Rectangle(base_x + 120.0, base_y, 60.0, 60.0), COLOR_3)
            Self._draw_tex_rect(rl, self.color_icon, ci_src, Rectangle(base_x + 180.0, base_y, 60.0, 60.0), COLOR_4)
            Self._draw_tex_rect(rl, self.color_icon, ci_src, Rectangle(base_x + 240.0, base_y, 60.0, 60.0), COLOR_5)

            var sel_idx = 0
            if self.color_selection == "2":
                sel_idx = 1
            elif self.color_selection == "3":
                sel_idx = 2
            elif self.color_selection == "4":
                sel_idx = 3
            elif self.color_selection == "5":
                sel_idx = 4
            rl.draw_rectangle_lines(base_x + Float32(sel_idx) * 60.0 + 5.0, base_y + 5.0, 50.0, 50.0, red)

        # Selection borders & indicators
        if self.player1_or_bot == 1:
            Self._draw_tex_rect(rl, self.player1_select, port_src, Rectangle(p1_fx, p1_fy, frame_w, frame_h))
        if self.player2_or_bot == 1:
            Self._draw_tex_rect(rl, self.player2_select, port_src, Rectangle(p2_fx, p2_fy, frame_w, frame_h))

        var net_label = "ONLINE (" + self.net.status_text + ") [N: Disconnect]" if self.net.enabled else "LOCAL MODE [N: Join Online Lobby]"
        var net_col = Vec4f(0.25, 1.0, 0.55, 1.0) if self.net.enabled else Vec4f(0.75, 0.88, 1.0, 1.0)
        self._text(rl, net_label, 40.0, WINDOW_HEIGHT - 45.0, 32.0, net_col)

        if self.player1_menu_selection == "1":
            Self._draw_tex_rect(rl, self.player_neutral_select, port_src, Rectangle(p1_fx, p1_fy, frame_w, frame_h), cyan)
        elif self.player1_menu_selection == "2":
            Self._draw_tex_rect(rl, self.player_neutral_select, port_src, Rectangle(p2_fx, p2_fy, frame_w, frame_h), cyan)

        var play_col = cyan if self.player1_menu_selection == "P" else white
        var quit_col = cyan if self.player1_menu_selection == "Q" else white
        self._text(rl, String(PLAY_STRING), 33.0 * WINDOW_WIDTH / 75.0, 2.0 * WINDOW_HEIGHT / 3.0, 64.0, play_col)
        self._text(rl, String(QUIT_STRING), 33.0 * WINDOW_WIDTH / 75.0, 475.0 * WINDOW_HEIGHT / 600.0, 64.0, quit_col)

    def draw_game_over_menu(mut self, mut rl: Raylib, logic: GameLogic) raises:
        rl.clear_background(Vec4f(20.0 / 255.0, 20.0 / 255.0, 150.0 / 255.0, 1.0))

        var white = Vec4f(1.0, 1.0, 1.0, 1.0)
        var black = Vec4f(0.0, 0.0, 0.0, 1.0)
        var title_str: String

        if logic.winner1:
            self.walrus1_animation.set_current_sprite(0, 0, False)
            Self._draw_tex_rect(
                rl,
                self.sprite_map_walrus,
                self.walrus1_animation.uv_rect,
                Rectangle(WINDOW_WIDTH / 2.0 - 80.0, WINDOW_HEIGHT / 4.0, 160.0, 160.0),
                logic.walrus1.get_color(),
            )
            title_str = logic.walrus1.get_name() + String(WON)
        else:
            self.walrus2_animation.set_current_sprite(0, 0, False)
            Self._draw_tex_rect(
                rl,
                self.sprite_map_walrus,
                self.walrus2_animation.uv_rect,
                Rectangle(WINDOW_WIDTH / 2.0 - 80.0, WINDOW_HEIGHT / 4.0, 160.0, 160.0),
                logic.walrus2.get_color(),
            )
            title_str = logic.walrus2.get_name() + String(WON)

        self._text(rl, title_str, WINDOW_WIDTH / 4.0, WINDOW_HEIGHT / 12.0, 72.0, white)

        var base_x = WINDOW_WIDTH / 4.0
        var base_y = 7.0 * WINDOW_HEIGHT / 12.0

        var rep_col = black if self.game_over_menu_selection == "P" else white
        var stat_col = black if self.game_over_menu_selection == "S" else white
        var quit_col = black if self.game_over_menu_selection == "Q" else white

        self._text(rl, String(REPLAY), base_x, base_y, 60.0, rep_col)
        self._text(rl, String(STATS_TEXT), base_x, base_y + 70.0, 60.0, stat_col)
        self._text(rl, String(QUIT_STRING), base_x, base_y + 140.0, 60.0, quit_col)

    def draw_stats_menu(self, mut rl: Raylib, logic: GameLogic) raises:
        rl.clear_background(Vec4f(137.0 / 255.0, 207.0 / 255.0, 240.0 / 255.0, 1.0))

        var black = Vec4f(0.0, 0.0, 0.0, 1.0)
        var x1 = WINDOW_WIDTH / 10.0
        var x2 = x1 + WINDOW_WIDTH / 2.0
        var y0 = WINDOW_HEIGHT / 10.0

        self._text(rl, logic.walrus1.get_name(), x1, y0, 64.0, black)
        self._text(rl, logic.walrus2.get_name(), x2, y0, 64.0, black)

        self._text(rl, String(KILLS) + String(logic.walrus1.kills), x1, y0 + 100.0, 36.0, black)
        self._text(rl, String(KILLS) + String(logic.walrus2.kills), x2, y0 + 100.0, 36.0, black)

        self._text(rl, String(DEATHS) + String(logic.walrus1.deaths), x1, y0 + 150.0, 36.0, black)
        self._text(rl, String(DEATHS) + String(logic.walrus2.deaths), x2, y0 + 150.0, 36.0, black)

        self._text(rl, String(POWERUPS) + String(logic.walrus1.powerups_collected), x1, y0 + 200.0, 36.0, black)
        self._text(rl, String(POWERUPS) + String(logic.walrus2.powerups_collected), x2, y0 + 200.0, 36.0, black)

        self._text(rl, String(SLASH_ATTACKS) + String(logic.walrus1.slash_attack_num), x1, y0 + 250.0, 36.0, black)
        self._text(rl, String(SLASH_ATTACKS) + String(logic.walrus2.slash_attack_num), x2, y0 + 250.0, 36.0, black)

        var dist1 = Int(logic.walrus1.distance_travelled) // 10
        var dist2 = Int(logic.walrus2.distance_travelled) // 10
        self._text(rl, String(DIST) + String(dist1), x1, y0 + 300.0, 36.0, black)
        self._text(rl, String(DIST) + String(dist2), x2, y0 + 300.0, 36.0, black)

        self._text(rl, String(MAIN_MENU), 2.0 * WINDOW_WIDTH / 5.0, WINDOW_HEIGHT - 100.0, 40.0, black)

    def draw_game(mut self, mut rl: Raylib, mut logic: GameLogic) raises:
        rl.clear_background(Vec4f(0.0, 0.0, 1.0, 1.0))

        # Screen shake offset
        var shake_x: Float32 = 0.0
        var shake_y: Float32 = 0.0
        if self.screenshake_timer > 0.0:
            var amp = Int(self.screenshake_magnitude * self.screenshake_timer * 0.3)
            if amp > 0:
                shake_x = Float32(self.rng.next_int(-amp // 2, amp // 2))
                shake_y = Float32(self.rng.next_int(-amp // 2, amp // 2))

        # Draw procedural arctic caustic water background
        var glfwGetTime = rl.glfw.get_function[c_double]("glfwGetTime")
        var t = Float32(glfwGetTime())
        self.water_shader.draw(rl.rl, rl.gl, -25.0 + shake_x, -25.0 + shake_y,
                               WINDOW_WIDTH + 50.0, WINDOW_HEIGHT + 50.0,
                               t, shake_x, shake_y)

        # Draw water background
        #Self._draw_tex_rect(
        #    rl,
        #    self.water,
        #    self.water_animation.uv_rect,
        #    Rectangle(-25.0 + shake_x, -25.0 + shake_y, WINDOW_WIDTH + 50.0, WINDOW_HEIGHT + 50.0),
        #)

        # Draw ice blocks
        var white = Vec4f(1.0, 1.0, 1.0, 1.0)
        ##var prog = logic.get_stage_progression()
        ##for i in range(ICE_BLOCKS_WIDTH + 2):
            ##for j in range(ICE_BLOCKS_HEIGHT + 2):
                ##var dura = logic.stage.get_tile_dura(i, j, prog)
                ##if dura > 0.0:
                    ##var bw = ICE_BLOCKS_SIZE_X * dura
                    ##var bh = ICE_BLOCKS_SIZE_Y * dura
                    ##var bx = Float32(i) * ICE_BLOCKS_SIZE_X + ((ICE_BLOCKS_SIZE_X - bw) / 2.0) + shake_x
                    ##var by = Float32(j) * ICE_BLOCKS_SIZE_Y + ((ICE_BLOCKS_SIZE_Y - bh) / 2.0) + shake_y
                    ##var ice_col = Vec4f(50.0 / 255.0, 247.0 / 255.0, 250.0 / 255.0, (230.0 * dura) / 255.0)
                    ##rl.draw_rectangle(bx, by, bw, bh, ice_col)
                    ##rl.draw_rectangle_lines(bx, by, bw, bh, white)
        # Draw ice blocks with organic neighbor-aware shorelines, 3D depth rims, and surface sheen
        # Pass 1: Draw all ice block rectangles, 3D depth lips, and shoreline rims (100% GL_TRIANGLES batch)
        var prog = logic.get_stage_progression()
        for i in range(ICE_BLOCKS_WIDTH + 2):
            for j in range(ICE_BLOCKS_HEIGHT + 2):
                var dura = logic.stage.get_tile_dura(i, j, prog)
                if dura > 0.0:
                    var bw = ICE_BLOCKS_SIZE_X * dura
                    var bh = ICE_BLOCKS_SIZE_Y * dura
                    var bx = Float32(i) * ICE_BLOCKS_SIZE_X + ((ICE_BLOCKS_SIZE_X - bw) / 2.0) + shake_x
                    var by = Float32(j) * ICE_BLOCKS_SIZE_Y + ((ICE_BLOCKS_SIZE_Y - bh) / 2.0) + shake_y
                    var alpha = (230.0 * dura) / 255.0

                    var shade = Float32((i * 7 + j * 13) % 5) * 0.035
                    var ice_col = Vec4f(
                        min((50.0 / 255.0) + shade, 1.0),
                        min((244.0 / 255.0) + shade * 0.4, 1.0),
                        1.0,
                        alpha,
                    )

                    var has_top   = (j > 0) and (logic.stage.get_tile_dura(i, j - 1, prog) > 0.85)
                    var has_bot   = (j < ICE_BLOCKS_HEIGHT + 1) and (logic.stage.get_tile_dura(i, j + 1, prog) > 0.85)
                    var has_left  = (i > 0) and (logic.stage.get_tile_dura(i - 1, j, prog) > 0.85)
                    var has_right = (i < ICE_BLOCKS_WIDTH + 1) and (logic.stage.get_tile_dura(i + 1, j, prog) > 0.85)

                    var lip_col = Vec4f(15.0 / 255.0, 145.0 / 255.0, 195.0 / 255.0, alpha * 0.9)
                    if not has_bot:
                        rl.draw_rectangle(bx, by + bh, bw, 6.0 * dura, lip_col)
                    if not has_left:
                        rl.draw_rectangle(bx - 2.0 * dura, by + 2.0, 2.0 * dura, bh, lip_col)
                    if not has_right:
                        rl.draw_rectangle(bx + bw, by + 2.0, 2.0 * dura, bh, lip_col)

                    rl.draw_rectangle(bx, by, bw, bh, ice_col)

                    var rim_col = Vec4f(1.0, 1.0, 1.0, alpha)
                    var rim_t: Float32 = 2.5 * dura
                    if not has_top:
                        rl.draw_rectangle(bx, by, bw, rim_t, rim_col)
                    if not has_bot:
                        rl.draw_rectangle(bx, by + bh - rim_t, bw, rim_t, rim_col)
                    if not has_left:
                        rl.draw_rectangle(bx, by, rim_t, bh, rim_col)
                    if not has_right:
                        rl.draw_rectangle(bx + bw - rim_t, by, rim_t, bh, rim_col)

        # Pass 2: Draw all glossy sheens and fracture cracks (100% GL_LINES batch)
        for i in range(ICE_BLOCKS_WIDTH + 2):
            for j in range(ICE_BLOCKS_HEIGHT + 2):
                var dura = logic.stage.get_tile_dura(i, j, prog)
                if dura > 0.0:
                    var bw = ICE_BLOCKS_SIZE_X * dura
                    var bh = ICE_BLOCKS_SIZE_Y * dura
                    var bx = Float32(i) * ICE_BLOCKS_SIZE_X + ((ICE_BLOCKS_SIZE_X - bw) / 2.0) + shake_x
                    var by = Float32(j) * ICE_BLOCKS_SIZE_Y + ((ICE_BLOCKS_SIZE_Y - bh) / 2.0) + shake_y

                    if dura > 0.72 and ((i + j) % 3 == 0):
                        var sheen = Vec4f(1.0, 1.0, 1.0, 0.28 * dura)
                        rl.draw_line(bx + bw * 0.22, by + bh * 0.65, bx + bw * 0.55, by + bh * 0.25, sheen)
                        rl.draw_line(bx + bw * 0.42, by + bh * 0.72, bx + bw * 0.68, by + bh * 0.40, sheen)
                    elif dura <= 0.72:
                        var crack = Vec4f(10.0 / 255.0, 110.0 / 255.0, 155.0 / 255.0, 0.55)
                        rl.draw_line(bx + bw * 0.20, by + bh * 0.25, bx + bw * 0.55, by + bh * 0.55, crack)
                        rl.draw_line(bx + bw * 0.55, by + bh * 0.55, bx + bw * 0.78, by + bh * 0.35, crack)



        # Draw splash
        if self.splash_timer > 0.0:
            if logic.walrus1.is_dead():
                var p1 = logic.walrus1.get_pos()
                Self._draw_tex_rect(
                    rl, self.walrus_splash, self.walrus_splash_anim.uv_rect,
                    Rectangle(p1[0] - 30.0 + shake_x, p1[1] - 30.0 + shake_y, 60.0, 60.0),
                )
            elif logic.walrus2.is_dead():
                var p2 = logic.walrus2.get_pos()
                Self._draw_tex_rect(
                    rl, self.walrus_splash, self.walrus_splash_anim.uv_rect,
                    Rectangle(p2[0] - 30.0 + shake_x, p2[1] - 30.0 + shake_y, 60.0, 60.0),
                )

        # Draw fish
        var num_fish = len(logic.fish_list)
        for i in range(num_fish):
            var f = logic.fish_list[i]
            var fp = f.get_position()
            var t = f.flop_progress_timer - 0.5
            var size_offset = FISH_SIZE + (-FISH_SIZE * t * t + 1.0)
            var anim_idx = i % len(self.fish_animation_list)
            self.fish_animation_list[anim_idx].set_current_sprite_y(Int(f.get_color()))
            Self._draw_tex_rect(
                rl,
                self.sprite_map_fish,
                self.fish_animation_list[anim_idx].uv_rect,
                Rectangle(fp[0] - size_offset + shake_x, fp[1] - size_offset + shake_y, size_offset * 2.0, size_offset * 2.0),
            )

        # Draw Walruses in Y-depth order
        if logic.walrus1.get_pos()[1] > logic.walrus2.get_pos()[1]:
            if not logic.walrus2.is_dead():
                self._draw_walrus(rl, logic.walrus2, self.walrus2_animation.uv_rect, shake_x, shake_y)
            if not logic.walrus1.is_dead():
                self._draw_walrus(rl, logic.walrus1, self.walrus1_animation.uv_rect, shake_x, shake_y)
        else:
            if not logic.walrus1.is_dead():
                self._draw_walrus(rl, logic.walrus1, self.walrus1_animation.uv_rect, shake_x, shake_y)
            if not logic.walrus2.is_dead():
                self._draw_walrus(rl, logic.walrus2, self.walrus2_animation.uv_rect, shake_x, shake_y)

        # Direction arrow prompts when an opponent is dead
        var red = Vec4f(1.0, 0.0, 0.0, 1.0)
        if logic.walrus1.is_dead():
            self._text(rl, String(GO_RIGHT), 3.0 * WINDOW_WIDTH / 4.0, (WINDOW_HEIGHT / 2.0) - 10.0, 72.0, red)
        elif logic.walrus2.is_dead():
            self._text(rl, String(GO_LEFT), WINDOW_WIDTH / 4.0 - 180.0, (WINDOW_HEIGHT / 2.0) - 10.0, 72.0, red)

        # Minimap platforms & active indicator
        var plat_src = Rectangle(0.0, 0.0, Float32(self.stage_progression.width), Float32(self.stage_progression.height))
        var act_src = Rectangle(0.0, 0.0, Float32(self.stage_progression_active.width), Float32(self.stage_progression_active.height))

        var r_l2 = Rectangle(190.0 * WINDOW_WIDTH / 800.0, -25.0 * WINDOW_HEIGHT / 600.0, 140.0 * WINDOW_WIDTH / 800.0, 100.0 * WINDOW_HEIGHT / 600.0)
        var r_l1 = Rectangle(240.0 * WINDOW_WIDTH / 800.0, -30.0 * WINDOW_HEIGHT / 600.0, 170.0 * WINDOW_WIDTH / 800.0, 120.0 * WINDOW_HEIGHT / 600.0)
        var r_c  = Rectangle(300.0 * WINDOW_WIDTH / 800.0, -35.0 * WINDOW_HEIGHT / 600.0, 200.0 * WINDOW_WIDTH / 800.0, 140.0 * WINDOW_HEIGHT / 600.0)
        var r_r1 = Rectangle(390.0 * WINDOW_WIDTH / 800.0, -30.0 * WINDOW_HEIGHT / 600.0, 170.0 * WINDOW_WIDTH / 800.0, 120.0 * WINDOW_HEIGHT / 600.0)
        var r_r2 = Rectangle(470.0 * WINDOW_WIDTH / 800.0, -25.0 * WINDOW_HEIGHT / 600.0, 140.0 * WINDOW_WIDTH / 800.0, 100.0 * WINDOW_HEIGHT / 600.0)

        Self._draw_tex_rect(rl, self.stage_progression, plat_src, r_l2)
        Self._draw_tex_rect(rl, self.stage_progression, plat_src, r_l1)
        Self._draw_tex_rect(rl, self.stage_progression, plat_src, r_c)
        Self._draw_tex_rect(rl, self.stage_progression, plat_src, r_r1)
        Self._draw_tex_rect(rl, self.stage_progression, plat_src, r_r2)

        if prog == -2:
            Self._draw_tex_rect(rl, self.stage_progression_active, act_src, r_l2)
        elif prog == -1:
            Self._draw_tex_rect(rl, self.stage_progression_active, act_src, r_l1)
        elif prog == 0:
            Self._draw_tex_rect(rl, self.stage_progression_active, act_src, r_c)
        elif prog == 1:
            Self._draw_tex_rect(rl, self.stage_progression_active, act_src, r_r1)
        elif prog == 2:
            Self._draw_tex_rect(rl, self.stage_progression_active, act_src, r_r2)

        # Trigger SFX & screen shake events
        if logic.player_hit > 0.0:
            self.sound_manager.play_sound(rl, SFX.BUMP, logic.player_hit)
            self.screenshake_magnitude = logic.player_hit
            self.screenshake_timer = 1.0
            logic.player_hit = 0.0
        if logic.player_bump > 0.0:
            self.sound_manager.play_sound(rl, SFX.BUMP, logic.player_bump)
            self.screenshake_magnitude = logic.player_bump
            self.screenshake_timer = 0.5
            logic.player_bump = 0.0
        if logic.border_bump > 0.0:
            self.sound_manager.play_sound(rl, SFX.BUMP, logic.border_bump)
            logic.border_bump = 0.0
        if logic.splash > 0.0:
            self.sound_manager.play_sound(rl, SFX.SPLASH, logic.splash)
            self.splash_timer = 0.5
            logic.splash = 0.0
        if logic.powerup > 0.0:
            self.sound_manager.play_sound(rl, SFX.FISH, logic.powerup)
            logic.powerup = 0.0

        # Stamina bars & gauges
        var bar_w = 300.0 * WINDOW_WIDTH / 800.0
        var bar_h = 25.0 * WINDOW_HEIGHT / 600.0
        var b1_x = 70.0 * WINDOW_WIDTH / 800.0
        var b1_y = 60.0 * WINDOW_HEIGHT / 600.0
        var b2_x = b1_x + bar_w + (70.0 * WINDOW_WIDTH / 800.0)

        var state1 = logic.walrus1.get_state()
        var state2 = logic.walrus2.get_state()

        var bg1 = Vec4f(1.0, 0.0, 0.0, 1.0)
        var fg1 = Vec4f(1.0, 1.0, 0.0, 1.0)
        if state1 == PlayerState.DEAD:
            bg1 = Vec4f(50.0 / 255.0, 50.0 / 255.0, 50.0 / 255.0, 1.0)
            fg1 = Vec4f(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0, 1.0)
        elif state1 == PlayerState.RESTING:
            bg1 = Vec4f(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0, 1.0)
            fg1 = Vec4f(150.0 / 255.0, 150.0 / 255.0, 150.0 / 255.0, 1.0)

        var bg2 = Vec4f(1.0, 0.0, 0.0, 1.0)
        var fg2 = Vec4f(1.0, 1.0, 0.0, 1.0)
        if state2 == PlayerState.DEAD:
            bg2 = Vec4f(50.0 / 255.0, 50.0 / 255.0, 50.0 / 255.0, 1.0)
            fg2 = Vec4f(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0, 1.0)
        elif state2 == PlayerState.RESTING:
            bg2 = Vec4f(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0, 1.0)
            fg2 = Vec4f(150.0 / 255.0, 150.0 / 255.0, 150.0 / 255.0, 1.0)

        var black = Vec4f(0.0, 0.0, 0.0, 1.0)
        rl.draw_rectangle(b1_x, b1_y, bar_w, bar_h, bg1)
        rl.draw_rectangle(b1_x, b1_y, bar_w * (logic.walrus1.get_stamina() / 100.0), bar_h, fg1)
        rl.draw_rectangle_lines(b1_x, b1_y, bar_w, bar_h, black)

        rl.draw_rectangle(b2_x, b1_y, bar_w, bar_h, bg2)
        rl.draw_rectangle(b2_x, b1_y, bar_w * (logic.walrus2.get_stamina() / 100.0), bar_h, fg2)
        rl.draw_rectangle_lines(b2_x, b1_y, bar_w, bar_h, black)

        # Round counter
        var rc_x = (WINDOW_WIDTH / 2.0) - 52.0
        var rnd = logic.get_round()
        if rnd < 10:
            Self._draw_tex_rect(
                rl, self.round_counter,
                Rectangle(0.0, 0.0, Float32(self.round_counter.width), Float32(self.round_counter.height)),
                Rectangle(rc_x, 82.0, 120.0, 120.0),
            )
            self._text(rl, String(rnd), rc_x + 55.0, 120.0, 42.0, white)
        elif rnd < 20:
            Self._draw_tex_rect(rl, self.round_counter_10, self.round_counter_10_anim.uv_rect, Rectangle(rc_x, 72.0, 120.0, 120.0))
            self._text(rl, String(rnd), rc_x + 43.0, 120.0, 42.0, white)
        else:
            Self._draw_tex_rect(rl, self.round_counter_20, self.round_counter_20_anim.uv_rect, Rectangle(rc_x, 72.0, 120.0, 120.0))
            self._text(rl, String(rnd), rc_x + 43.0, 120.0, 42.0, white)

        self._text(rl, "Round", rc_x + 35.0, 108.0, 24.0, white)

        # Player names over stamina bars (ice cyan with heavy black drop shadow)
        var name1 = logic.walrus1.get_name()
        var name2 = logic.walrus2.get_name()
        var ice_cyan = Vec4f(0.55, 0.95, 1.0, 1.0)

        var tag_sz: Float32 = 40.0
        var tag_y = b1_y + (bar_h - tag_sz * UI_FONT_SCALE) * 0.5 - 5.0
        self._text(rl, name1, b1_x + 7.0, tag_y + 2.0, tag_sz, black)
        self._text(rl, name1, b1_x + 5.0, tag_y, tag_sz, ice_cyan)
        self._text(rl, name2, b2_x + 7.0, tag_y + 2.0, tag_sz, black)
        self._text(rl, name2, b2_x + 5.0, tag_y, tag_sz, ice_cyan)

        # Draw bot AI rays in debug mode
        if self.debug_mode:
            if not logic.walrus1.is_dead() and self.player1_or_bot == -1:
                _ = self.bot1_controller.update(
                    rl, logic.walrus1, logic.walrus2, logic.stage, prog, logic.fish_list, 0.0, 1, True
                )
            if not logic.walrus2.is_dead() and self.player2_or_bot == -1:
                _ = self.bot2_controller.update(
                    rl, logic.walrus2, logic.walrus1, logic.stage, prog, logic.fish_list, 0.0, 2, True
                )

    def _draw_walrus(
        mut self, mut rl: Raylib, walrus: Player, uv: Rectangle, shake_x: Float32, shake_y: Float32
    ) raises:
        var mass = walrus.get_mass()
        var pos = walrus.get_pos()
        var charge = walrus.get_attack_charge()
        var jitter_max = Int(2.0 * charge)
        var jx: Float32 = Float32(self.rng.next_int(0, jitter_max)) if jitter_max > 0 else 0.0
        var jy: Float32 = Float32(self.rng.next_int(0, jitter_max)) if jitter_max > 0 else 0.0
        var dst = Rectangle(
            (pos[0] - mass / 2.0) + jx + shake_x,
            (pos[1] - mass / 2.0) + jy + shake_y,
            mass,
            mass,
        )
        Self._draw_tex_rect(rl, self.sprite_map_walrus, uv, dst, walrus.get_color())

        # Attack charge red glow overlay
        if charge > 0.0:
            var flash = sin(15.0 * charge) * 0.5 + 0.5
            var alpha = min((40.0 * charge) / 255.0, 1.0)
            Self._draw_tex_rect(rl, self.sprite_map_walrus, uv, dst, Vec4f(flash, 0.0, 0.0, alpha))

    def menu_up(mut self, mut rl: Raylib, logic: GameLogic) raises:
        var state = logic.get_state()
        if state == GameStateEnum.MAIN_MENU:
            if self.main_menu_selection == "P" or self.main_menu_selection == "H":
                self.main_menu_selection = "P"
            elif self.main_menu_selection == "O":
                self.main_menu_selection = "H"
        elif state == GameStateEnum.OPTIONS_MENU:
            if self.options_menu_selection == "S" or self.options_menu_selection == "M":
                self.options_menu_selection = "S"
            elif self.options_menu_selection == "Q":
                self.options_menu_selection = "M"
        elif state == GameStateEnum.GAME_OVER_MENU:
            if self.game_over_menu_selection == "P" or self.game_over_menu_selection == "S":
                self.game_over_menu_selection = "P"
            elif self.game_over_menu_selection == "Q":
                self.game_over_menu_selection = "S"
        elif state == GameStateEnum.PLAYER_SELECT_MENU:
            if self.player1_menu_selection == "P":
                self.player1_menu_selection = "1"
            elif self.player1_menu_selection == "Q":
                self.player1_menu_selection = "P"
        elif state == GameStateEnum.PAUSE_MENU:
            if self.pause_menu_selection == "Q":
                self.pause_menu_selection = "R"
        self.sound_manager.play_sound(rl, SFX.MENU_MOVE, logic.get_sfx_volume())

    def menu_down(mut self, mut rl: Raylib, logic: GameLogic) raises:
        var state = logic.get_state()
        if state == GameStateEnum.MAIN_MENU:
            if self.main_menu_selection == "O" or self.main_menu_selection == "H":
                self.main_menu_selection = "O"
            elif self.main_menu_selection == "P":
                self.main_menu_selection = "H"
        elif state == GameStateEnum.OPTIONS_MENU:
            if self.options_menu_selection == "S":
                self.options_menu_selection = "M"
            elif self.options_menu_selection == "M" or self.options_menu_selection == "Q":
                self.options_menu_selection = "Q"
        elif state == GameStateEnum.GAME_OVER_MENU:
            if self.game_over_menu_selection == "Q" or self.game_over_menu_selection == "S":
                self.game_over_menu_selection = "Q"
            elif self.game_over_menu_selection == "P":
                self.game_over_menu_selection = "S"
        elif state == GameStateEnum.PLAYER_SELECT_MENU:
            if self.player1_menu_selection == "P":
                self.player1_menu_selection = "Q"
            elif self.player1_menu_selection == "1" or self.player1_menu_selection == "2":
                self.player1_menu_selection = "P"
        elif state == GameStateEnum.PAUSE_MENU:
            if self.pause_menu_selection == "R":
                self.pause_menu_selection = "Q"
        self.sound_manager.play_sound(rl, SFX.MENU_MOVE, logic.get_sfx_volume())

    def menu_left(mut self, mut rl: Raylib, mut logic: GameLogic) raises:
        var state = logic.get_state()
        if state == GameStateEnum.OPTIONS_MENU:
            if self.options_menu_selection == "S":
                var v = logic.get_sfx_volume() - 10.0
                logic.set_sfx_volume(v)
            elif self.options_menu_selection == "M":
                var v = logic.get_music_volume() - 10.0
                logic.set_music_volume(v)
        elif state == GameStateEnum.PLAYER_SELECT_MENU:
            if self.player1_menu_selection == "2":
                self.player1_menu_selection = "1"
        elif state == GameStateEnum.COLOR_SELECT_SUBMENU:
            if self.color_selection == "2":
                self.color_selection = "1"
            elif self.color_selection == "3":
                self.color_selection = "2"
            elif self.color_selection == "4":
                self.color_selection = "3"
            elif self.color_selection == "5":
                self.color_selection = "4"
        self.sound_manager.play_sound(rl, SFX.MENU_MOVE, logic.get_sfx_volume())

    def menu_right(mut self, mut rl: Raylib, mut logic: GameLogic) raises:
        var state = logic.get_state()
        if state == GameStateEnum.OPTIONS_MENU:
            if self.options_menu_selection == "S":
                var v = logic.get_sfx_volume() + 10.0
                logic.set_sfx_volume(v)
            elif self.options_menu_selection == "M":
                var v = logic.get_music_volume() + 10.0
                logic.set_music_volume(v)
        elif state == GameStateEnum.PLAYER_SELECT_MENU:
            if self.player1_menu_selection == "1":
                self.player1_menu_selection = "2"
        elif state == GameStateEnum.COLOR_SELECT_SUBMENU:
            if self.color_selection == "4":
                self.color_selection = "5"
            elif self.color_selection == "3":
                self.color_selection = "4"
            elif self.color_selection == "2":
                self.color_selection = "3"
            elif self.color_selection == "1":
                self.color_selection = "2"
        self.sound_manager.play_sound(rl, SFX.MENU_MOVE, logic.get_sfx_volume())

    def menu_select(mut self, mut rl: Raylib, mut logic: GameLogic) raises:
        var state = logic.get_state()
        if state == GameStateEnum.MAIN_MENU:
            if self.main_menu_selection == "P":
                logic.handle_player_select_menu()
            elif self.main_menu_selection == "H":
                logic.handle_help_menu()
            elif self.main_menu_selection == "O":
                logic.handle_options_menu()
        elif state == GameStateEnum.GAME_OVER_MENU:
            if self.game_over_menu_selection == "P":
                logic.handle_player_select_menu()
                self.sound_manager.play_music(rl, MusicTrack.TITLE)
            elif self.game_over_menu_selection == "S":
                logic.handle_stats_menu()
                self.sound_manager.play_music(rl, MusicTrack.TITLE)
            else:
                logic.return_to_menu()
                self.sound_manager.play_music(rl, MusicTrack.TITLE)
        elif state == GameStateEnum.HELP_MENU:
            logic.return_to_menu()
        elif state == GameStateEnum.OPTIONS_MENU:
            if self.options_menu_selection == "Q":
                self.options_menu_selection = "S"
                logic.return_to_menu()
        elif state == GameStateEnum.PLAYER_SELECT_MENU:
            if self.player1_menu_selection == "P":
                self.sound_manager.play_music(rl, MusicTrack.BATTLE)
                logic.reset_game()
            elif self.player1_menu_selection == "Q":
                self.player1_menu_selection = "P"
                logic.return_to_menu()
            elif self.player1_menu_selection == "1":
                self.last_edited_slot = 1
                self.player1_or_bot = -self.player1_or_bot
                if self.player1_or_bot == 1:
                    self.entering_name_text = True
                    logic.handle_name_text_submenu()
                    self.walrus1_name_str = ""
            elif self.player1_menu_selection == "2":
                self.last_edited_slot = 2
                self.player2_or_bot = -self.player2_or_bot
                if self.player2_or_bot == 1:
                    self.entering_name_text = True
                    logic.handle_name_text_submenu()
                    self.walrus2_name_str = ""
        elif state == GameStateEnum.PAUSE_MENU:
            if self.pause_menu_selection == "Q":
                logic.return_to_menu()
                self.sound_manager.play_music(rl, MusicTrack.TITLE)
            elif self.pause_menu_selection == "R":
                logic.toggle_pause()
        elif state == GameStateEnum.STATS_MENU:
            logic.return_to_menu()
        elif state == GameStateEnum.NAME_TEXT_SUBMENU:
            if self.player1_menu_selection == "1":
                logic.walrus1.set_name(
                    self.walrus1_name_str if self.walrus1_name_str.byte_length() > 0 else String(DEFAULT_NAME_1)
                )
            else:
                logic.walrus2.set_name(
                    self.walrus2_name_str if self.walrus2_name_str.byte_length() > 0 else String(DEFAULT_NAME_2)
                )
            self.entering_name_text = False
            self.color_selector = True
            logic.handle_color_select_submenu()
        elif state == GameStateEnum.COLOR_SELECT_SUBMENU:
            self.color_selector = False
            logic.handle_player_select_menu()

        self.sound_manager.play_sound(rl, SFX.MENU_SELECT, logic.get_sfx_volume())

    def _poll_typed_char(self, rl: Raylib) -> String:
        for k in range(KEY_A, KEY_Z + 1):
            if rl.is_key_pressed(k):
                return chr(Int(k))
        for k in range(KEY_0, KEY_9 + 1):
            if rl.is_key_pressed(k):
                return chr(Int(k))
        return ""

    def process_input(mut self, mut rl: Raylib, mut logic: GameLogic, d_sec: Float32) raises:
        self.water_animation.update_water(d_sec)
        self.sound_manager.update_music(rl, d_sec)

        if self.screenshake_timer > 0.0:
            self.screenshake_timer -= d_sec
            if self.screenshake_timer < 0.0:
                self.screenshake_timer = 0.0

        var was_started = self.net.match_started
        var prev_state = logic.get_state()
        self.net.poll(logic)
        if self.net.has_peer_profile:
            self.net.has_peer_profile = False
            if self.net.local_player_num == 1:
                if self.net.local_name.byte_length() > 0:
                    self.walrus1_name_str = self.net.local_name
                    logic.walrus1.set_name(self.net.local_name)
                logic.walrus1.set_color(self.net.local_color)
                if self.net.peer_name.byte_length() > 0:
                    self.walrus2_name_str = self.net.peer_name
                    logic.walrus2.set_name(self.net.peer_name)
                logic.walrus2.set_color(self.net.peer_color)
            elif self.net.local_player_num == 2:
                if self.net.peer_name.byte_length() > 0:
                    self.walrus1_name_str = self.net.peer_name
                    logic.walrus1.set_name(self.net.peer_name)
                logic.walrus1.set_color(self.net.peer_color)
                if self.net.local_name.byte_length() > 0:
                    self.walrus2_name_str = self.net.local_name
                    logic.walrus2.set_name(self.net.local_name)
                logic.walrus2.set_color(self.net.local_color)

        if (self.net.match_started and not was_started) or (
            self.net.match_started and prev_state != GameStateEnum.PLAYING and logic.get_state() == GameStateEnum.PLAYING
        ):
            self.player1_or_bot = 1
            self.player2_or_bot = 1
            self.sound_manager.play_music(rl, MusicTrack.BATTLE)

        var state = logic.get_state()
        if state == GameStateEnum.PLAYING:
            for i in range(len(self.fish_animation_list)):
                self.fish_animation_list[i].update_fish(d_sec)

            var prog = logic.get_stage_progression()
            var paused = False

            if self.net.match_started and self.net.local_player_num == 2:
                # Online Guest (Player 2): animate both walruses and send local inputs to Host
                self.walrus1_animation.update_walrus(logic.walrus1.get_facing_dir(), logic.walrus1.get_state(), d_sec)
                self.walrus2_animation.update_walrus(logic.walrus2.get_facing_dir(), logic.walrus2.get_state(), d_sec)

                var g_dx: Float32 = 0.0
                var g_dy: Float32 = 0.0
                if rl.is_key_down(KEY_W) or rl.is_key_down(KEY_UP):
                    g_dy -= 1.0
                if rl.is_key_down(KEY_S) or rl.is_key_down(KEY_DOWN):
                    g_dy += 1.0
                if rl.is_key_down(KEY_A) or rl.is_key_down(KEY_LEFT):
                    g_dx -= 1.0
                if rl.is_key_down(KEY_D) or rl.is_key_down(KEY_RIGHT):
                    g_dx += 1.0
                var g_slash = rl.is_key_down(KEY_LEFT_SHIFT) or rl.is_key_down(KEY_RIGHT_SHIFT)
                self.net.send_guest_input(g_dx, g_dy, g_slash, d_sec)

            elif self.net.match_started and self.net.local_player_num == 1:
                # Online Host (Player 1): control Walrus 1 locally, apply Guest inputs to Walrus 2, broadcast snapshot
                if not logic.walrus1.is_dead():
                    self.walrus1_animation.update_walrus(logic.walrus1.get_facing_dir(), logic.walrus1.get_state(), d_sec)
                    paused = paused or self.player_controller.update(rl, logic.walrus1, d_sec, 1)

                if not logic.walrus2.is_dead():
                    self.walrus2_animation.update_walrus(logic.walrus2.get_facing_dir(), logic.walrus2.get_state(), d_sec)
                    if self.net.remote_p2_slash and logic.walrus2.get_stamina() >= 30.0:
                        logic.walrus2.raise_tusks(d_sec)
                    var p2_dir = Vec2f(self.net.remote_p2_dx, self.net.remote_p2_dy)
                    logic.walrus2.apply_active_force(p2_dir, d_sec)
            else:
                # Local 1P / 2P / Bot match
                if not logic.walrus1.is_dead():
                    self.walrus1_animation.update_walrus(logic.walrus1.get_facing_dir(), logic.walrus1.get_state(), d_sec)
                    if self.player1_or_bot == 1:
                        paused = paused or self.player_controller.update(rl, logic.walrus1, d_sec, 1)
                    else:
                        paused = paused or self.bot1_controller.update(
                            rl, logic.walrus1, logic.walrus2, logic.stage, prog, logic.fish_list, d_sec, 1, False
                        )

                if not logic.walrus2.is_dead():
                    self.walrus2_animation.update_walrus(logic.walrus2.get_facing_dir(), logic.walrus2.get_state(), d_sec)
                    if self.player2_or_bot == 1:
                        paused = paused or self.player_controller.update(rl, logic.walrus2, d_sec, 2)
                    else:
                        paused = paused or self.bot2_controller.update(
                            rl, logic.walrus2, logic.walrus1, logic.stage, prog, logic.fish_list, d_sec, 2, False
                        )

            if paused:
                logic.toggle_pause()

            self.round_counter_10_anim.update_round_fire(d_sec)
            self.round_counter_20_anim.update_round_fire(d_sec)
            self.walrus_splash_anim.update_walrus_splash(d_sec)

            if self.splash_timer > 0.0:
                self.splash_timer -= d_sec
                if self.splash_timer < 0.0:
                    self.splash_timer = 0.0
        else:
            if not self.entering_name_text:
                if state == GameStateEnum.PLAYER_SELECT_MENU:
                    if rl.is_key_pressed(KEY_N) or rl.is_key_pressed(345):
                        if self.net.enabled:
                            self.net.disconnect()
                        else:
                            if self.last_edited_slot == 2:
                                self.net.local_name = self.walrus2_name_str
                                self.net.local_color = logic.walrus2.get_color()
                            else:
                                self.net.local_name = self.walrus1_name_str
                                self.net.local_color = logic.walrus1.get_color()
                            _ = self.net.connect(self.server_url, "lobby")
                        self.sound_manager.play_sound(rl, SFX.MENU_SELECT, logic.get_sfx_volume())

                var can_control_menu = (not self.net.match_started) or (self.net.local_player_num == 1)
                if can_control_menu:
                    if rl.is_key_pressed(KEY_UP) or rl.is_key_pressed(KEY_W):
                        self.menu_up(rl, logic)
                    elif rl.is_key_pressed(KEY_DOWN) or rl.is_key_pressed(KEY_S):
                        self.menu_down(rl, logic)
                    elif rl.is_key_pressed(KEY_RIGHT) or rl.is_key_pressed(KEY_D):
                        self.menu_right(rl, logic)
                    elif rl.is_key_pressed(KEY_LEFT) or rl.is_key_pressed(KEY_A):
                        self.menu_left(rl, logic)
                    elif rl.is_key_pressed(KEY_ENTER) or rl.is_key_pressed(KEY_SPACE):
                        self.menu_select(rl, logic)

                if rl.is_key_pressed(KEY_P):
                    logic.toggle_pause()
                    self.sound_manager.play_sound(rl, SFX.MENU_SELECT, logic.get_sfx_volume())
                elif rl.is_key_pressed(KEY_GRAVE):
                    self.debug_mode = not self.debug_mode
            else:
                if rl.is_key_pressed(KEY_ENTER):
                    self.menu_select(rl, logic)
                elif rl.is_key_pressed(KEY_BACKSPACE):
                    if self.player1_menu_selection == "1" and self.walrus1_name_str.byte_length() > 0:
                        var trimmed = String(self.walrus1_name_str[byte=0 : self.walrus1_name_str.byte_length() - 1])
                        self.walrus1_name_str = trimmed
                    elif self.player1_menu_selection != "1" and self.walrus2_name_str.byte_length() > 0:
                        var trimmed = String(self.walrus2_name_str[byte=0 : self.walrus2_name_str.byte_length() - 1])
                        self.walrus2_name_str = trimmed
                else:
                    var ch = self._poll_typed_char(rl)
                    if ch.byte_length() > 0:
                        if self.player1_menu_selection == "1" and self.walrus1_name_str.byte_length() < MAX_INPUT_SIZE:
                            self.walrus1_name_str += ch
                        elif self.player1_menu_selection != "1" and self.walrus2_name_str.byte_length() < MAX_INPUT_SIZE:
                            self.walrus2_name_str += ch

        self.net.send_host_snapshot(logic, d_sec)
