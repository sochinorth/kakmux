"""Send one request to kak-tree-sitter the way a well-behaved client may:
write, shut down the write side (EOF), then close a moment later."""
import json, os, socket, sys, time
sock_path, session, buf, sel = sys.argv[1:5]
req = {"metadata": {"session": session, "client": "client0", "buffer": buf},
       "payload": {"type": "nav", "selections": sel, "dir": "parent"}}
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(sock_path)
s.sendall(json.dumps(req).encode())
s.shutdown(socket.SHUT_WR)
time.sleep(0.3)
s.close()
