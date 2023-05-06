import os
import shutil
import subprocess
import threading
import traceback
import zipfile
from io import BytesIO
from tempfile import TemporaryDirectory
from uuid import uuid4

from flask import Flask, request


VALID_DRIVERS = ('latex', 'pdflatex', 'lualatex', 'xelatex')


app = Flask(__name__)
runtime_cache = TemporaryDirectory()


class UserException(Exception):
    pass


class ServerException(Exception):
    pass


class LatexRunner(object):
    def __init__(self, tex_driver, main_filename, zip_contents, cache=None):
        self.tex_driver = tex_driver
        self.main_filename = main_filename
        self.zip_contents = zip_contents
        self.cache = cache

        self.should_delete = self.cache is None
        self.timeout = 60
        self.latex_process = None
        self.pdf_bytes = None

    def run(self):
        f = BytesIO(self.zip_contents)

        if self.cache:
            unzip_path = os.path.join(runtime_cache.name, self.cache)
        else:
            unzip_path = os.path.join(runtime_cache.name, str(uuid4()))

        try:
            z = zipfile.ZipFile(f)

            print('Running {} on files: {}'.format(
                self.tex_driver, z.namelist()
            ))

            if self.main_filename not in z.namelist():
                raise UserException('{} not found in zip payload'.format(
                    self.main_filename
                ))

            z.extractall(unzip_path)
        except zipfile.BadZipFile as e:
            raise UserException() from e

        def thread_target():
            self.run_tex_at_path(unzip_path)

        thread = threading.Thread(target=thread_target)
        thread.start()
        thread.join(self.timeout)

        failed = False
        if thread.is_alive():
            failed = True
            print('Build process took more than {} seconds...'.format(
                self.timeout
            ))
            self.latex_process.terminate()
            thread.join()

        if self.should_delete:
            print('Deleting unzip path, because cache shouldn\'t persist')
            shutil.rmtree(unzip_path)

        if failed:
            raise ServerException('Failed to build in time')

        if self.latex_process.returncode != 0:
            raise UserException('Build failed')

        print('Writing out {} bytes'.format(len(self.pdf_bytes)))
        return self.pdf_bytes, 200

    def run_tex_at_path(self, p):
        self.latex_process = subprocess.Popen(
            [self.tex_driver, self.main_filename], cwd=p
        )

        self.latex_process.communicate()

        if self.latex_process.returncode != 0:
            raise UserException(
                '{} process failed. Check logs for more details.'.format(
                    self.tex_driver
                )
            )

        pdf_filename = self.main_filename.replace('.tex', '.pdf')
        pdf_path = os.path.join(p, pdf_filename)

        if not os.path.isfile(pdf_path):
            raise ServerException('Failed to find file {}'.format(pdf_path))

        pdf_file = open(pdf_path, 'rb')
        pdf_bytes = pdf_file.read()
        pdf_file.close()
        self.pdf_bytes = pdf_bytes


@app.route("/<tex_driver>/<main_filename>", methods=["POST"])
def route_latex(tex_driver, main_filename):
    return do_latex(tex_driver, main_filename)


@app.route("/<tex_driver>/<main_filename>/<cache_key>", methods=["POST"])
def route_latex_cache(tex_driver, main_filename, cache_key):
    return do_latex(tex_driver, main_filename, cache_key)


@app.route("/health", methods=["GET"])
def health():
    return '', 200


def do_latex(tex_driver, main_filename, cache_key=None):
    if tex_driver not in VALID_DRIVERS:
        return 'Must provide a valid driver ({})'.format(VALID_DRIVERS), 400

    if not main_filename:
        return 'Must provide a filename to build', 400

    request_data = request.get_data()
    lr = LatexRunner(tex_driver, main_filename, request_data, cache_key)

    try:
        return lr.run()
    except UserException:
        return traceback.format_exc(), 400
    except ServerException:
        return traceback.format_exc(), 500


if __name__ == '__main__':
    port = os.getenv('PORT')
    if port is None or port == '':
        port = '8080'
    app.run(debug=True, host='0.0.0.0', port=port)
