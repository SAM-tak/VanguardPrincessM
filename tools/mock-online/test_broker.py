"""Protocol checks for retries, ordering, session isolation and departure."""
import json
import socket
import time
import unittest

from broker import Broker


class BrokerTest(unittest.TestCase):
    def setUp(self):
        self.broker = Broker()
        self.peers = []

    def tearDown(self):
        self.broker.sock.close()
        for peer in self.peers:
            peer.close()

    def peer(self, number):
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind(("127.0.0.1", 0))
        sock.settimeout(0.1)
        self.peers.append(sock)
        return f"local-player-{number}", sock

    def request(self, peer, seq, **body):
        player, sock = peer
        self.broker.receive(json.dumps({"token": self.broker.token, "player": player,
                                       "seq": seq, "body": body}), sock.getsockname())

    def test_reordered_and_duplicate_requests(self):
        peer = self.peer(1)
        self.request(peer, 1, op="login")
        self.request(peer, 3, op="create", bucket="test", capacity=16)
        self.assertFalse(self.broker.rooms)
        self.request(peer, 2, op="ping")
        self.request(peer, 3, op="create", bucket="test", capacity=16)
        self.assertEqual(len(self.broker.rooms), 1)
        self.assertEqual(self.broker.serial, 1)

    def test_retry_retains_sequence_and_ack_releases_pending(self):
        peer = self.peer(1)
        self.request(peer, 1, op="login")
        client = self.broker.clients[peer[0]]
        message, _ = client["pending"][1]
        old = time.monotonic() - 1
        client["pending"][1] = (message, old)
        self.broker.tick()
        self.assertEqual(client["pending"][1][0]["seq"], 1)
        self.assertGreater(client["pending"][1][1], old)
        self.broker.receive(json.dumps({"token": self.broker.token, "player": peer[0], "ack": 1}), peer[1].getsockname())
        self.assertFalse(client["pending"])

    def test_departing_owner_closes_room_and_notifies_guest(self):
        owner, guest = self.peer(1), self.peer(2)
        for peer in (owner, guest):
            self.request(peer, 1, op="login")
        self.request(owner, 2, op="create", bucket="test", capacity=16)
        room_id = next(iter(self.broker.rooms))
        self.request(guest, 2, op="join", room=room_id)
        self.request(owner, 3, op="leave")
        self.assertFalse(self.broker.rooms)
        client = self.broker.clients[guest[0]]
        self.assertEqual(client["room"], "")
        self.assertTrue(any(message["body"].get("kind") == "lobbyClosed"
                            for message, _ in client["pending"].values()))

    def test_wrong_session_is_ignored(self):
        peer = self.peer(1)
        self.broker.receive(json.dumps({"token": "another-session", "player": peer[0],
                                       "seq": 1, "body": {"op": "login"}}), peer[1].getsockname())
        self.assertFalse(self.broker.clients)


if __name__ == "__main__":
    unittest.main()
