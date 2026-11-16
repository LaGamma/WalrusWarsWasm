from std.collections import List
from gammaraylib import WebSocketClient, Vec2f, Vec4f
from gamelogic import GameLogic, GameStateEnum
from player import PlayerState
from fish import Fish
from stage import GRID_W, GRID_H

struct NetClient(Movable):
    var ws: WebSocketClient
    var enabled: Bool
    var connected: Bool
    var match_started: Bool
    var local_player_num: Int  # 0 = unassigned, 1 = Host (Walrus 1), 2 = Guest (Walrus 2)
    var room_id: String
    var status_text: String
    var send_accum: Float32
    var input_accum: Float32
    var map_accum: Float32
    var last_sent_state: Int

    var local_name: String
    var local_color: Vec4f
    var peer_name: String
    var peer_color: Vec4f
    var has_peer_profile: Bool

    # Latest input received from Guest (Player 2) when we are Host (Player 1)
    var remote_p2_dx: Float32
    var remote_p2_dy: Float32
    var remote_p2_slash: Bool

    def __init__(out self) raises:
        self.ws = WebSocketClient()
        self.enabled = False
        self.connected = False
        self.match_started = False
        self.local_player_num = 0
        self.room_id = "lobby"
        self.status_text = "Offline"
        self.send_accum = 0.0
        self.input_accum = 0.0
        self.map_accum = 0.0
        self.last_sent_state = -1
        self.remote_p2_dx = 0.0
        self.remote_p2_dy = 0.0
        self.remote_p2_slash = False
        self.local_name = ""
        self.local_color = Vec4f(1.0, 1.0, 1.0, 1.0)
        self.peer_name = ""
        self.peer_color = Vec4f(1.0, 1.0, 1.0, 1.0)
        self.has_peer_profile = False

    def connect(mut self, mut url: String, room: String = "lobby") raises -> Bool:
        self.room_id = room
        self.match_started = False
        self.local_player_num = 0
        self.connected = False
        self.enabled = True
        self.status_text = "Connecting..."
        if not self.ws.connect(url):
            self.status_text = "Connection failed"
            self.enabled = False
            return False
        return True

    def disconnect(mut self) raises:
        if self.enabled:
            self.ws.close()
        self.enabled = False
        self.connected = False
        self.match_started = False
        self.local_player_num = 0
        self.status_text = "Offline"

    def poll(mut self, mut logic: GameLogic) raises:
        if not self.enabled:
            return

        if not self.connected and self.ws.is_open():
            self.connected = True
            var join_msg = "JOIN|" + self.room_id
            _ = self.ws.send(join_msg)
            self.status_text = "Joining room..."

        for _ in range(32):
            var msg = self.ws.poll()
            if msg.byte_length() == 0:
                break
            self._handle_message(msg, logic)

    def _handle_message(mut self, msg: String, mut logic: GameLogic) raises:
        var parts = msg.split("|")
        if len(parts) == 0:
            return

        var tag = String(parts[0])
        if tag == "WELCOME" and len(parts) >= 2:
            self.local_player_num = Int(atol(String(parts[1])))
            self.send_profile()
            self.status_text = "Waiting for P2..." if self.local_player_num == 1 else "Joined as P2!"
        elif tag == "START":
            self.send_profile()
            self.match_started = True
            self.status_text = "Online Match Active"
            logic.stage.generate_map(logic.rng)
            logic.reset_game()
        elif tag == "PEER_LEFT":
            self.match_started = False
            self.status_text = "Opponent disconnected"
        elif tag == "ERR" and len(parts) >= 2:
            self.status_text = "Error: " + String(parts[1])
        elif tag == "I" and len(parts) >= 4 and self.local_player_num == 1:
            self.remote_p2_dx = Float32(atof(String(parts[1])))
            self.remote_p2_dy = Float32(atof(String(parts[2])))
            self.remote_p2_slash = Int(atol(String(parts[3]))) != 0
        elif tag == "P" and len(parts) >= 6:
            self.peer_name = String(parts[2])
            var r = Float32(atof(String(parts[3])))
            var g = Float32(atof(String(parts[4])))
            var b = Float32(atof(String(parts[5])))
            self.peer_color = Vec4f(r, g, b, 1.0)
            self.has_peer_profile = True
        elif tag == "M" and len(parts) >= 3 and self.local_player_num == 2:
            var prog = Int(atol(String(parts[1])))
            logic.progression = prog
            var grid_str = String(parts[2])
            var bytes = grid_str.as_bytes()
            var k = 0
            for i in range(GRID_W):
                for j in range(GRID_H):
                    if k < len(bytes):
                        var q = Int(bytes[k]) - 65
                        if q < 0:
                            q = 0
                        elif q > 20:
                            q = 20
                        logic.stage.set_tile_dura(i, j, prog, Float32(q) * 0.05)
                    k += 1
        elif tag == "S" and len(parts) >= 22 and self.local_player_num == 2:
            logic.walrus1.pos = Vec2f(Float32(atof(String(parts[1]))), Float32(atof(String(parts[2]))))
            logic.walrus1.vel = Vec2f(Float32(atof(String(parts[3]))), Float32(atof(String(parts[4]))))
            logic.walrus1.facing_dir = Vec2f(Float32(atof(String(parts[5]))), Float32(atof(String(parts[6]))))
            logic.walrus1.stamina = Float32(atof(String(parts[7])))
            logic.walrus1.state = PlayerState(Int(atol(String(parts[8]))))

            logic.walrus2.pos = Vec2f(Float32(atof(String(parts[9]))), Float32(atof(String(parts[10]))))
            logic.walrus2.vel = Vec2f(Float32(atof(String(parts[11]))), Float32(atof(String(parts[12]))))
            logic.walrus2.facing_dir = Vec2f(Float32(atof(String(parts[13]))), Float32(atof(String(parts[14]))))
            logic.walrus2.stamina = Float32(atof(String(parts[15])))
            logic.walrus2.state = PlayerState(Int(atol(String(parts[16]))))

            logic.progression = Int(atol(String(parts[17])))
            logic.state = GameStateEnum(Int(atol(String(parts[18]))))
            logic.winner1 = Int(atol(String(parts[19]))) != 0
            logic.round = Int(atol(String(parts[20])))

            var fish_count = Int(atol(String(parts[21])))
            logic.fish_list.clear()
            var base = 22
            for _ in range(fish_count):
                if base + 2 >= len(parts):
                    break
                var fx = Float32(atof(String(parts[base])))
                var fy = Float32(atof(String(parts[base + 1])))
                var fcolor = UInt32(atol(String(parts[base + 2])))
                var fish = Fish(Vec2f(fx, fy), Vec2f(0.0, 0.0), logic.rng)
                fish.color = fcolor
                logic.fish_list.append(fish)
                base += 3

    def send_guest_input(mut self, dx: Float32, dy: Float32, slash: Bool, d_sec: Float32) raises:
        if not self.match_started or self.local_player_num != 2:
            return
        self.input_accum += d_sec
        if self.input_accum < 0.033:
            return
        self.input_accum = 0.0

        var slash_flag = "1" if slash else "0"
        var pkt = "I|" + String(dx) + "|" + String(dy) + "|" + slash_flag
        _ = self.ws.send(pkt)

    def send_host_snapshot(mut self, logic: GameLogic, d_sec: Float32) raises:
        if not self.match_started or self.local_player_num != 1:
            return

        var cur_state = logic.state.value
        var state_changed = cur_state != self.last_sent_state

        self.send_accum += d_sec
        self.map_accum += d_sec
        if not state_changed and self.send_accum < 0.033:
            return
        self.send_accum = 0.0
        self.last_sent_state = cur_state

        var w1p = logic.walrus1.pos
        var w1v = logic.walrus1.vel
        var w1f = logic.walrus1.facing_dir
        var w2p = logic.walrus2.pos
        var w2v = logic.walrus2.vel
        var w2f = logic.walrus2.facing_dir
        var win_flag = "1" if logic.winner1 else "0"
        var n_fish = len(logic.fish_list)

        var pkt = (
            "S|"
            + String(w1p[0]) + "|" + String(w1p[1]) + "|"
            + String(w1v[0]) + "|" + String(w1v[1]) + "|"
            + String(w1f[0]) + "|" + String(w1f[1]) + "|"
            + String(logic.walrus1.stamina) + "|" + String(logic.walrus1.state.value) + "|"
            + String(w2p[0]) + "|" + String(w2p[1]) + "|"
            + String(w2v[0]) + "|" + String(w2v[1]) + "|"
            + String(w2f[0]) + "|" + String(w2f[1]) + "|"
            + String(logic.walrus2.stamina) + "|" + String(logic.walrus2.state.value) + "|"
            + String(logic.progression) + "|"
            + String(cur_state) + "|"
            + win_flag + "|"
            + String(logic.round) + "|"
            + String(n_fish)
        )
        for i in range(n_fish):
            var fp = logic.fish_list[i].pos
            pkt += "|" + String(fp[0]) + "|" + String(fp[1]) + "|" + String(logic.fish_list[i].color)

        _ = self.ws.send(pkt)

        if state_changed or self.map_accum >= 0.15:
            self.map_accum = 0.0
            var prog = logic.get_stage_progression()
            var map_pkt = "M|" + String(prog) + "|"
            for i in range(GRID_W):
                for j in range(GRID_H):
                    var q = Int(logic.stage.get_tile_dura(i, j, prog) * 20.0 + 0.5)
                    if q < 0:
                        q = 0
                    elif q > 20:
                        q = 20
                    map_pkt += chr(65 + q)
            _ = self.ws.send(map_pkt)

    def send_profile(mut self) raises:
        if not self.enabled or not self.connected:
            return
        var clean_name = self.local_name.replace("|", " ")
        var pkt = (
            "P|"
            + String(self.local_player_num)
            + "|"
            + clean_name
            + "|"
            + String(self.local_color[0])
            + "|"
            + String(self.local_color[1])
            + "|"
            + String(self.local_color[2])
        )
        _ = self.ws.send(pkt)
