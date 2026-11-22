# Socket I/O
import logging
import os

from flask import Flask, render_template
from flask_socketio import SocketIO
from modules import settings

# Socket I/O
# ====================================================#
PORT = int(os.environ.get("PORT", "5050"))
HOST = "0.0.0.0"
app = Flask(__name__)
app.debug = False
socketio = SocketIO(app, async_mode="threading", logger=False)
logging.getLogger("werkzeug").setLevel(logging.ERROR)  # remove socket io logs


def sendMsg(namespace, obj):
    socketio.emit(namespace, obj, namespace="/socket")


@app.route("/")
def index():
    print("Someone Connected!")
    sendMsg("response", settings.read())
    return render_template("index.html")
