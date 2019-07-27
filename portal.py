from flask import Flask, request, render_template
from flask_socketio import SocketIO, emit
import requests
import os
import json

application = Flask(__name__, template_folder='.')
socketio = SocketIO(application)

@application.route('/health')
def health():
    return json.dumps(True)

@application.route('/')
def dashboard():
    socket_uri = os.environ['SOCKET_URI']
    hardware_host = os.environ['HARDWARE_HOST']
    result = requests.get('http://' + hardware_host + '/hardware/').json()
    return render_template("index.html", len = len(result), result = result, socket_uri = socket_uri)

@socketio.on('connect')
def connect():
    hardware_host = os.environ['HARDWARE_HOST']
    statuses = requests.get('http://' + hardware_host + '/hardware/availability').json()
    emit('availability', statuses)

if __name__ == "__main__":
    socketio.run(application, host='0.0.0.0', port=5000)
