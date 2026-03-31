import json
import os

from flask import Flask

app = Flask(__name__)
port = int(os.environ.get("PORT", 8080))


@app.route("/")
def hello():
    return "Hello from distroless buildpack builder!"


@app.route("/health")
def health():
    return json.dumps({"status": "OK"}), 200, {"Content-Type": "application/json"}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=port)
