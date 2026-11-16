#!/usr/bin/env python3
"""
Walrus Wars 2-Player WebSocket Room Relay Server.

Protocol (pipe-delimited UTF-8 text frames):
  Client -> Server:
    JOIN|<room_id>                Join or create a 2-player room (default: "lobby")
    I|<dx>|<dy>|<slash>           Guest (P2) input frame
    S|<serialized_world_state>    Host (P1) authoritative state snapshot

  Server -> Client:
    WELCOME|<1_or_2>              Assigned player slot (1 = Host/Walrus 1, 2 = Guest/Walrus 2)
    START                         Sent to both players once 2 clients are in the room
    PEER_LEFT                     Sent to remaining player if peer disconnects
    ERR|<reason>                  Room full or invalid handshake
"""
import asyncio
import mimetypes
import os
from http import HTTPStatus
from pathlib import Path
import websockets
from websockets.asyncio.server import ServerConnection
from websockets.datastructures import Headers
from websockets.http11 import Response

DIST_DIR = Path(__file__).resolve().parent.parent / "dist"

MAX_PLAYERS_PER_ROOM = 2
rooms: dict[str, list[ServerConnection]] = {}


async def broadcast(players: list[ServerConnection], msg: str, exclude: ServerConnection | None = None) -> None:
    for peer in list(players):
        if peer is not exclude:
            try:
                await peer.send(msg)
            except websockets.ConnectionClosed:
                pass


async def handle_client(ws: ServerConnection) -> None:
    room_id = "lobby"
    joined = False
    try:
        raw = await asyncio.wait_for(ws.recv(), timeout=15.0)
        if not isinstance(raw, str):
            await ws.send("ERR|expected_text_join")
            return

        parts = raw.strip().split("|", 1)
        if parts[0] != "JOIN":
            await ws.send("ERR|expected_JOIN")
            return

        if len(parts) > 1 and parts[1].strip():
            room_id = parts[1].strip()[:32]

        players = rooms.setdefault(room_id, [])
        if len(players) >= MAX_PLAYERS_PER_ROOM:
            await ws.send("ERR|room_full")
            return

        role = len(players) + 1  # 1 = Host (Walrus 1), 2 = Guest (Walrus 2)
        players.append(ws)
        joined = True

        print(f"[ws] Client joined room '{room_id}' as Player {role} ({len(players)}/2)")
        await ws.send(f"WELCOME|{role}")

        if len(players) == MAX_PLAYERS_PER_ROOM:
            print(f"[ws] Room '{room_id}' full — starting match!")
            await broadcast(players, "START")

        # Relay gameplay packets (inputs & state snapshots) directly to peer
        async for packet in ws:
            if isinstance(packet, str):
                await broadcast(players, packet, exclude=ws)

    except (asyncio.TimeoutError, websockets.ConnectionClosed):
        pass
    finally:
        if joined and room_id in rooms and ws in rooms[room_id]:
            rooms[room_id].remove(ws)
            print(f"[ws] Player disconnected from room '{room_id}' ({len(rooms[room_id])}/2 remaining)")
            await broadcast(rooms[room_id], "PEER_LEFT")
            if not rooms[room_id]:
                del rooms[room_id]

def serve_static(connection: ServerConnection, request):
    if request.headers.get("Upgrade", "").lower() == "websocket":
        print("[ws] Incoming WS upgrade:", request.path)
        return None
    rel = request.path.split("?", 1)[0].lstrip("/") or "index.html"
    file_path = (DIST_DIR / rel).resolve()
    if not str(file_path).startswith(str(DIST_DIR.resolve())) or not file_path.is_file():
        return connection.respond(HTTPStatus.NOT_FOUND, "Not Found\n")

    body = file_path.read_bytes()
    guessed, _ = mimetypes.guess_type(str(file_path))
    if file_path.suffix == ".wasm":
        ctype = "application/wasm"
    elif file_path.suffix == ".js":
        ctype = "application/javascript"
    else:
        ctype = guessed or "application/octet-stream"

    headers = Headers(
        [
            ("Content-Type", ctype),
            ("Content-Length", str(len(body))),
            ("Cache-Control", "no-store"),
        ]
    )
    return Response(200, "OK", headers, body)

async def main() -> None:
    host = os.environ.get("WS_HOST", "127.0.0.1")
    port = int(os.environ.get("WS_PORT", "8000"))
    async with websockets.serve(
        handle_client,
        host,
        port,
        process_request=serve_static,
        origins=None,
    ):
        print(f"[ws] Walrus Wars HTTP + WebSocket server listening on http://{host}:{port}")
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
