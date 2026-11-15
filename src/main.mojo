from std.ffi import external_call
from std.sys import size_of, is_defined
from gammaraylib import *
from definitions import *
from gamelogic import GameLogic
from cameraview import CameraView


struct WalrusApp:
    var rl: Raylib
    var logic: GameLogic
    var view: CameraView

    def __init__(out self, fullscreen: Bool = False) raises:
        self.rl = Raylib(
            Int(WINDOW_WIDTH),
            Int(WINDOW_HEIGHT),
            String(APP_TITLE),
            fullscreen=fullscreen,
        )
        self.rl.default_font = self.rl.load_font("assets/font/menuFont.ttf")
        self.logic = GameLogic()
        self.logic.init()
        self.view = CameraView(self.rl)

    def step(mut self) raises:
        var d_sec = self.rl.get_frame_time()
        # Clamp delta time so tab-switching doesn't cause huge physics jumps
        if d_sec > 0.05:
            d_sec = 0.05

        self.view.process_input(self.rl, self.logic, d_sec)
        self.logic.update(d_sec)
        self.view.draw(self.rl, self.logic)


@export
def init_game() abi("C") -> Pointer[WalrusApp, MutAnyOrigin]:
    var ptr = external_call["malloc", Pointer[WalrusApp, MutAnyOrigin]](
        size_of[WalrusApp]()
    )
    try:
        ptr.unsafe_write(WalrusApp(fullscreen=False))
    except e:
        print("Failed to init Walrus Wars:", e)
    return ptr


@export
def update_game(app: Pointer[WalrusApp, MutAnyOrigin]) abi("C"):
    try:
        app[].step()
    except e:
        print("Frame error:", e)


def main() raises:
    comptime if not is_defined["WASM"]():
        var app = WalrusApp(fullscreen=True)
        while not app.rl.window_should_close():
            app.step()
        app.rl.close()
