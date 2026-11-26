from flask import Flask
import logging
import os

app = Flask(__name__)

# Si APP_LOG_FILE est défini, j'écris aussi les journaux dans ce fichier.
log_file = os.environ.get('APP_LOG_FILE')
if log_file:
    log_handler = logging.FileHandler(log_file)
    log_handler.setFormatter(
        logging.Formatter('%(asctime)s %(levelname)s %(message)s'))
    app.logger.addHandler(log_handler)
    app.logger.setLevel(logging.INFO)


@app.route('/')
def hello():
    app.logger.info('Home endpoint requested')
    return f"Hello from DevStream! DB: {os.environ.get('DB_HOST', 'unknown')}"


@app.route('/health')
def health():
    app.logger.info('Health endpoint requested')
    return "OK", 200


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
