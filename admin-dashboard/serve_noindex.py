from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import argparse
import os


class NoIndexHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("X-Robots-Tag", "noindex, nofollow, noarchive, nosnippet, noimageindex")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=5179)
    parser.add_argument("--directory", default=os.path.dirname(__file__))
    args = parser.parse_args()

    handler = lambda *handler_args, **handler_kwargs: NoIndexHandler(
        *handler_args,
        directory=args.directory,
        **handler_kwargs,
    )
    server = ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    print(f"Serving admin dashboard at http://localhost:{args.port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
