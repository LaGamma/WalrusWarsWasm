from gammaraylib import Raylib, Sound
from std.ffi import OwnedDLHandle, c_float

struct MusicTrack(Equatable, ImplicitlyCopyable, Movable):
    var value: Int

    comptime NONE   = Self(0)
    comptime TITLE  = Self(1)
    comptime BATTLE = Self(2)

    def __init__(out self, value: Int):
        self.value = value
    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value
    def __ne__(self, other: Self) -> Bool:
        return self.value != other.value

struct SFX(Copyable, Equatable, ImplicitlyCopyable, Movable):
    var value: Int

    comptime BUMP        = Self(0)
    comptime SPLASH      = Self(1)
    comptime MENU_SELECT = Self(2)
    comptime MENU_MOVE   = Self(3)
    comptime FISH        = Self(4)

    def __init__(out self, value: Int):
        self.value = value
    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value
    def __ne__(self, other: Self) -> Bool:
        return self.value != other.value

struct SoundManager(Copyable, Movable):
    var bump_sound: Sound
    var splash_sound: Sound
    var menu_select_sound: Sound
    var menu_move_sound: Sound
    var fish_sound: Sound

    var menu_music: Sound
    var battle_music: Sound
    var current_music: MusicTrack
    var music_volume: Float32
    var music_timer: Float32

    def __init__(out self, mut rl: Raylib) raises:
        # Load SFX from assets/audio/ (falls back to procedural sounds if files are missing)
        self.bump_sound = Self._load_or_fallback(rl, "assets/audio/bump.wav", 180.0, 0.08)
        self.splash_sound = Self._load_or_fallback(rl, "assets/audio/splash.wav", 120.0, 0.25)
        self.menu_select_sound = Self._load_or_fallback(rl, "assets/audio/menuSelect.wav", 880.0, 0.06)
        self.menu_move_sound = Self._load_or_fallback(rl, "assets/audio/menuMove.wav", 520.0, 0.04)
        self.fish_sound = Self._load_or_fallback(rl, "assets/audio/fish.wav", 1100.0, 0.09)

        # Load background music tracks
        self.menu_music = Self._load_or_fallback(rl, "assets/audio/menuMusic.wav", 440.0, 0.01)
        self.battle_music = Self._load_or_fallback(rl, "assets/audio/battleMusic.wav", 440.0, 0.01)

        self.current_music = MusicTrack.NONE
        self.music_volume = 0.5
        self.music_timer = 0.0

    @staticmethod
    def _load_or_fallback(mut rl: Raylib, path: String, freq: Float32, dur: Float32) raises -> Sound:
        try:
            return rl.load_sound(path)
        except:
            print("Could not load audio, using procedural fallback:", path)
            return rl.gen_sound_click(freq=freq, duration_sec=dur)

    def play_sound(self, mut rl: Raylib, sfx: SFX, vol: Float32) raises:
        # Convert SFML's 0..100 volume scale to Raylib's 0.0..1.0 scale
        var norm_vol = min(max(vol / 100.0, 0.0), 1.0)

        if sfx == SFX.BUMP:
            self.bump_sound.set_volume(norm_vol)
            rl.play_sound(self.bump_sound)
        elif sfx == SFX.SPLASH:
            var splash_vol = min((vol * 3.5) / 100.0, 1.0)
            self.splash_sound.set_volume(splash_vol)
            rl.play_sound(self.splash_sound)
        elif sfx == SFX.MENU_SELECT:
            self.menu_select_sound.set_volume(norm_vol)
            rl.play_sound(self.menu_select_sound)
        elif sfx == SFX.MENU_MOVE:
            self.menu_move_sound.set_volume(norm_vol)
            rl.play_sound(self.menu_move_sound)
        elif sfx == SFX.FISH:
            self.fish_sound.set_volume(norm_vol)
            rl.play_sound(self.fish_sound)

    def play_music(mut self, mut rl: Raylib, track: MusicTrack) raises:
        if self.current_music == track:
            if track == MusicTrack.TITLE and self.menu_music.is_playing():
                return
            if track == MusicTrack.BATTLE and self.battle_music.is_playing():
                return

        self.current_music = track
        if track == MusicTrack.TITLE:
            self.battle_music.stop()
            self.menu_music.set_volume(self.music_volume)
            rl.play_sound(self.menu_music)
        elif track == MusicTrack.BATTLE:
            self.menu_music.stop()
            self.battle_music.set_volume(self.music_volume)
            rl.play_sound(self.battle_music)

    def update_music(mut self, mut rl: Raylib, d_sec: Float32) raises:
        if self.current_music == MusicTrack.TITLE:
            if not self.menu_music.is_playing():
                rl.play_sound(self.menu_music)
        elif self.current_music == MusicTrack.BATTLE:
            if not self.battle_music.is_playing():
                rl.play_sound(self.battle_music)

    def set_music_volume(mut self, volume: Float32):
        var new_vol = min(max(volume / 100.0, 0.0), 1.0)
        if new_vol == self.music_volume:
            return
        self.music_volume = new_vol
        self.battle_music.set_volume(self.music_volume)
        self.menu_music.set_volume(self.music_volume)

    def unload(mut self):
        self.bump_sound.unload()
        self.splash_sound.unload()
        self.menu_select_sound.unload()
        self.menu_move_sound.unload()
        self.fish_sound.unload()
        self.menu_music.unload()
        self.battle_music.unload()
