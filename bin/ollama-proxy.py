from flask import Flask, request, Response
import requests, sys

app = Flask(__name__)
OLLAMA_URL = "http://localhost:11434"

@app.before_request
def log_request():
    print(f">> {request.method} {request.path}", flush=True)

@app.route('/', methods=['HEAD', 'GET'])
def health():
    return '', 200

@app.route('/v1/messages/count_tokens', methods=['POST'])
def mock_count():
    return {"input_tokens": 0, "output_tokens": 0}, 200

@app.route('/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE'])
def proxy(path):
    resp = requests.request(
        method=request.method,
        url=f"{OLLAMA_URL}/{path}",
        headers={k: v for k, v in request.headers if k.lower() != 'host'},
        data=request.get_data(),
        cookies=request.cookies,
        allow_redirects=False,
        stream=True
    )
    return Response(resp.iter_content(chunk_size=1024), resp.status_code, resp.headers.items())

if __name__ == '__main__':
    app.run(port=11435, threaded=True)
