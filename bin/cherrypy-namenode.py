#!/usr/bin/python

import sys

service_name = "cherrypy-namenode"
pidfile_path = "/var/run/" + service_name + ".pid"
port = 8003

if len(sys.argv) > 1 and sys.argv[1] == "service_name": print service_name; sys.exit(0)
if len(sys.argv) > 1 and sys.argv[1] == "pidfile_path": print pidfile_path; sys.exit(0)
if len(sys.argv) > 1 and sys.argv[1] == "port": print port; sys.exit(0)

import cherrypy, os, subprocess
from cherrypy.process.plugins import PIDFile
p = PIDFile(cherrypy.engine, pidfile_path)
p.subscribe()

script_dir = os.path.dirname(os.path.realpath(__file__))

class ScriptRunner:
    @cherrypy.expose
    def add(self, host=None):
        if not host: cherrypy.HTTPError(400, "Host parameter is required.")
        self.execute_command('bash ' + script_dir + '/add-hadoop-slave.sh ' + host)

    @cherrypy.expose
    def remove(self, host=None):
        if not host: cherrypy.HTTPError(400, "Host parameter is required.")
        self.execute_command('bash ' + script_dir + '/remove-hadoop-slave.sh ' + host)

    @cherrypy.expose
    def list(self):
        self.execute_command("bash -c \"cat $HADOOP_CONF_DIR/slaves\"")

    def execute_command(self, command):
        try:
            return subprocess.check_output(command, shell=True)
        except subprocess.CalledProcessError as e:
            raise cherrypy.HTTPError(500, e.cmd + " exited with code " + str(e.returncode) + "\n" + e.output)

conf = {
    'global': {
        'server.socket_host': '127.0.0.1',
        'server.socket_port': port,
        'server.thread_pool': 1
    }
}

cherrypy.quickstart(ScriptRunner(), '/hadoop_slaves/', conf)
