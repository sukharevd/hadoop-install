#!/usr/bin/python

import sys

service_name = "cherrypy-vpn"
pidfile_path = "/var/run/" + service_name + ".pid"
port = 8002

if len(sys.argv) > 1 and sys.argv[1] == "service_name": print service_name; sys.exit(0)
if len(sys.argv) > 1 and sys.argv[1] == "pidfile_path": print pidfile_path; sys.exit(0)
if len(sys.argv) > 1 and sys.argv[1] == "port": print port; sys.exit(0)

import cherrypy, os, subprocess, mimetypes
from cherrypy.process.plugins import PIDFile
p = PIDFile(cherrypy.engine, pidfile_path)
p.subscribe()

script_dir = os.path.dirname(os.path.realpath(__file__))

class ScriptRunner:
    @cherrypy.expose
    def add(self, hostname=None, ip=None):
        if not hostname: raise cherrypy.HTTPError(400, "Hostname parameter is required.")
        if not ip: raise cherrypy.HTTPError(400, "IP parameter is required.")
        script_output = self.execute_command('bash ' + script_dir + '/add-vpn-client.sh "' + hostname + '" "' + ip + '"')
        filename=script_output.split('\n')[-2]

        if not os.path.exists(filename):
            return "file not found: " + filename
        f = open(filename, 'rb')
        size = os.path.getsize(filename)
        mime = mimetypes.guess_type(filename)[0]
        cherrypy.response.headers["Content-Type"] = mime
        cherrypy.response.headers["Content-Disposition"] = 'attachment; filename="%s"' % os.path.basename(filename)
        cherrypy.response.headers["Content-Length"] = size

        BUF_SIZE = 1024 * 5

        def stream():
            data = f.read(BUF_SIZE)
            while len(data) > 0:
                yield data
                data = f.read(BUF_SIZE)

        return stream()

    def execute_command(self, command):
        try:
            return subprocess.check_output(command, shell=True)
        except subprocess.CalledProcessError as e:
            raise cherrypy.HTTPError(500, e.cmd + " exited with code " + str(e.returncode) + "\n" + e.output)

conf = {
    'global': {
        'server.socket_host': '127.0.0.1',
        'server.socket_port': port,
        'server.thread_pool': 1,
        'response.stream': True,
    }
}

cherrypy.quickstart(ScriptRunner(), '/vpn-clients/', conf)
