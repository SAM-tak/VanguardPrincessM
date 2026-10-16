"""Development-only EOS substitute, shared by independent local game windows.

Loopback UDP carries JSON with acknowledgements and ordered retransmission.
It deliberately makes no contact with Epic services and needs no SDK DLL.
"""
import argparse
import json
import secrets
import socket
import time
from pathlib import Path


class Broker:
    def __init__(self, port=0):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4 * 1024 * 1024)
        self.sock.bind(("127.0.0.1", port))
        if hasattr(socket, "SIO_UDP_CONNRESET"):
            self.sock.ioctl(socket.SIO_UDP_CONNRESET, False)
        self.sock.settimeout(0.02)
        self.token = secrets.token_hex(16)
        self.clients = {}
        self.rooms = {}
        self.serial = 0

    def send(self, address, value):
        try:
            self.sock.sendto(json.dumps(value, ensure_ascii=True, separators=(",", ":")).encode(), address)
        except OSError:
            # Delivery remains pending; a closed window or a full local
            # socket buffer must not stop the broker for the other users.
            pass

    def deliver(self, player, body):
        client = self.clients.get(player)
        if not client:
            return
        seq = client["out"]
        client["out"] += 1
        message = {"token": self.token, "seq": seq, "body": body}
        client["pending"][seq] = (message, time.monotonic())
        self.send(client["address"], message)

    def event(self, player, kind, ok=True, peer="", code="Success"):
        self.deliver(player, {"op": "event", "kind": kind, "ok": ok, "peerId": peer, "code": code})

    def info(self, room):
        return {key: room[key] for key in ("id", "owner", "bucket", "capacity", "name", "locked")} | {
            "available": room["capacity"] - len(room["members"])}

    def roster(self, room):
        for player in room["members"]:
            self.deliver(player, {"op": "roster", "room": self.info(room), "members": room["members"]})

    def leave(self, player):
        client = self.clients.get(player)
        if not client:
            return
        room = self.rooms.get(client["room"])
        client["room"] = ""
        if not room:
            return
        room["members"].remove(player)
        if room["owner"] == player:
            del self.rooms[room["id"]]
            for other in room["members"]:
                self.clients[other]["room"] = ""
                self.event(other, "lobbyClosed")
        else:
            self.roster(room)
            for other in room["members"]:
                self.event(other, "memberLeft", peer=player)

    def command(self, player, body):
        client = self.clients[player]
        op = body.get("op")
        room = self.rooms.get(client["room"])
        if op == "login":
            self.event(player, "login")
        elif op == "create":
            self.leave(player)
            self.serial += 1
            room = {"id": f"local-room-{self.serial}", "owner": player,
                    "bucket": body["bucket"], "capacity": body["capacity"],
                    "name": "", "locked": False, "members": [player]}
            self.rooms[room["id"]] = room
            client["room"] = room["id"]
            self.roster(room)
            self.event(player, "created")
        elif op == "search":
            found = [self.info(r) for r in self.rooms.values() if r["bucket"] == body["bucket"]]
            self.deliver(player, {"op": "results", "rooms": found[:body["limit"]]})
            self.event(player, "search")
        elif op == "join":
            target = self.rooms.get(body["room"])
            if not target or len(target["members"]) >= target["capacity"]:
                self.event(player, "joined", False, code="RoomUnavailable")
            else:
                self.leave(player)
                target["members"].append(player)
                client["room"] = target["id"]
                self.roster(target)
                self.event(player, "joined")
        elif op == "setRoom" and room and room["owner"] == player:
            room["name"], room["locked"] = body["name"], body["locked"]
            self.roster(room)
            self.event(player, "roomUpdated")
        elif op == "leave":
            self.leave(player)
            self.event(player, "left")
        elif op == "kick" and room and room["owner"] == player and body["peer"] in room["members"]:
            self.leave(body["peer"])
            self.event(body["peer"], "memberLeft", peer=body["peer"])
            self.event(player, "kicked")
        elif op == "packet" and room and body["peer"] in room["members"]:
            self.deliver(body["peer"], {"op": "packet", "peerId": player,
                                      "channel": body["channel"], "bytes": body["bytes"]})

    def receive(self, raw, address):
        if address[0] != "127.0.0.1":
            return
        message = json.loads(raw)
        if message.get("token") != self.token:
            return
        player = message.get("player")
        if not isinstance(player, str) or not player.startswith("local-player-"):
            return
        client = self.clients.get(player)
        if message.get("op") == "disconnect":
            if client and client["address"] == address:
                self.leave(player)
                del self.clients[player]
            return
        if not client or client["address"] != address:
            if message.get("seq") != 1:
                return
            self.leave(player)
            client = {"address": address, "room": "", "next": 1, "out": 1,
                      "waiting": {}, "pending": {}, "seen": time.monotonic()}
            self.clients[player] = client
        client["seen"] = time.monotonic()
        if "ack" in message:
            client["pending"].pop(message["ack"], None)
            return
        seq = message.get("seq")
        if not isinstance(seq, int) or seq < 1 or seq > client["next"] + 4096:
            return
        self.send(address, {"token": self.token, "ack": seq})
        if seq >= client["next"]:
            client["waiting"][seq] = message["body"]
        while client["next"] in client["waiting"]:
            self.command(player, client["waiting"].pop(client["next"]))
            client["next"] += 1

    def tick(self):
        now = time.monotonic()
        for player, client in list(self.clients.items()):
            if now - client["seen"] > 15:
                self.leave(player)
                del self.clients[player]
                continue
            for seq, (message, sent) in list(client["pending"].items()):
                if now - sent >= 0.2:
                    self.send(client["address"], message)
                    client["pending"][seq] = (message, now)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ready-file", required=True, type=Path)
    args = parser.parse_args()
    broker = Broker()
    temporary = args.ready_file.with_suffix(".tmp")
    temporary.write_text(json.dumps({"port": broker.sock.getsockname()[1], "token": broker.token}), encoding="utf-8")
    temporary.replace(args.ready_file)
    print(f"Local mock EOS listening on 127.0.0.1:{broker.sock.getsockname()[1]}", flush=True)
    while True:
        try:
            raw, address = broker.sock.recvfrom(65536)
            broker.receive(raw, address)
        except socket.timeout:
            pass
        except (ValueError, KeyError, TypeError) as error:
            print(f"Ignored invalid development packet: {error}", flush=True)
        broker.tick()


if __name__ == "__main__":
    main()
