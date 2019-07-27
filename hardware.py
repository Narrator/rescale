from flask import Flask, request, jsonify
import pymysql
import time
import random
import os
import json

application = Flask(__name__)

host = os.environ['DB_HOST']
user = os.environ['DB_USER']
password = os.environ['DB_PASS']
db = os.environ['DB_NAME']

def slow_process_to_calculate_availability(provider, name):
    time.sleep(5)
    return random.choice(['HIGH', 'MEDIUM', 'LOW'])

@application.route('/health')
def health():
    return json.dumps(True)

@application.route('/hardware/')
def hardware():

    con = pymysql.connect(host=host, user=user, password=password, db=db)
    c = con.cursor()
    c.execute('SELECT provider, name from hardware')

    statuses = [
        {
            'provider': row[0],
            'name': row[1]
        }
        for row in c.fetchall()
    ]

    con.close()

    return jsonify(statuses)

@application.route('/hardware/availability')
def hardware_availability():
    con = pymysql.connect(host=host, user=user, password=password, db=db)
    c = con.cursor()
    c.execute('SELECT provider, name from hardware')
    statuses = [
        {
            'provider': row[0],
            'availability': slow_process_to_calculate_availability(row[0],row[1])
        }
        for row in c.fetchall()
    ]
    return jsonify(statuses)

if __name__ == '__main__':
    application.run(host='0.0.0.0', port=5001)