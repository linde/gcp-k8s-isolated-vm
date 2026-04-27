from flask import Flask, request, jsonify
import urllib.request
import urllib.parse
import json

app = Flask(__name__)

@app.route('/healthz')
def healthz():
    return "OK"

@app.route('/')
def proxy():
    url = request.args.get('url', 'http://httpbin.org/ip')
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req) as response:
            status = response.getcode()
            body = response.read().decode('utf-8')
        
        return jsonify({
            "message": "Successfully proxied ingress and egress", 
            "target_url": url, 
            "body": body, 
            "status": status
        })
    except Exception as e:
        return jsonify({"error": "Proxy request failed", "details": str(e)}), 500
