import os
import subprocess
import traceback
import zipfile
from io import BytesIO
from tempfile import TemporaryDirectory
from threading import Timer
from uuid import uuid4

from flask import Flask, request


VALID_DRIVERS = ('latex', 'pdflatex', 'lualatex', 'xelatex')


app = Flask(__name__)
runtime_cache = TemporaryDirectory()


@app.route("/<tex_driver>/<main_filename>", methods=["POST"])
def route_latex(tex_driver, main_filename):
    return do_latex(tex_driver, main_filename)


@app.route("/<tex_driver>/<main_filename>/<cache_key>", methods=["POST"])
def route_latex_cache(tex_driver, main_filename, cache_key):
    return do_latex(tex_driver, main_filename, cache_key)


def do_latex(tex_driver, main_filename, cache_key=None):
    if tex_driver not in VALID_DRIVERS:
        return 'Must provide a valid driver ({})'.format(VALID_DRIVERS), 400

    if not main_filename:
        return 'Must provide a filename to build', 400

    request_data = request.get_data()
    f = BytesIO(request_data)
    print('Got file of length {}'.format(len(request_data)))

    try:
        z = zipfile.ZipFile(f)

        if main_filename not in z.namelist():
            return '{} not found in payload'.format(main_filename), 400

        if cache_key:
            unzip_path = os.path.join(runtime_cache.name, cache_key)
        else:
            unzip_path = os.path.join(runtime_cache.name, str(uuid4()))

        z.extractall(unzip_path)
        p = subprocess.Popen([tex_driver, main_filename], cwd=unzip_path)

        timer = Timer(60, p.kill)
        try:
            timer.start()
            p.communicate()
        except Exception as e:
            print(traceback.format_exc())
            return str(e), 500
        finally:
            timer.cancel()

        pdf_filename = main_filename.replace('.tex', '.pdf')
        pdf_path = os.path.join(unzip_path, pdf_filename)

        pdf_file = open(pdf_path, 'rb')
        pdf_bytes = pdf_file.read()
        pdf_file.close()

        print('Writing out {} bytes'.format(len(pdf_bytes)))
        return pdf_bytes, 200
    except zipfile.BadZipFile as e:
        print(traceback.format_exc())
        return str(e), 400


if __name__ == '__main__':
    port = os.getenv('PORT')
    if port is None or port == '':
        port = '8080'
    app.run(debug=True, host='0.0.0.0', port=port)
