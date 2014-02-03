#!/usr/bin/python

import sys

service_name = "cherrypy-dns"
pidfile_path = "/var/run/" + service_name + ".pid"
port = 8001

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
    def add(self, hostname="", ip=""):
        return self.execute_command('bash ' + script_dir + '/add-domain-name.sh "' + hostname + '" "' + ip + '"')

    @cherrypy.expose
    def remove(self, hostname=None, ip=None):
        if not hostname: raise cherrypy.HTTPError(400, "Hostname parameter is required.")
        if not ip: raise cherrypy.HTTPError(400, "IP parameter is required.")
        return self.execute_command('bash ' + script_dir + '/remove-domain-name.sh "' + hostname + '" "' + ip + '"')

    #@cherrypy.expose
    #def lookup(self, attr):
    #    return subprocess.check_output('bash -c "cat $HADOOP_CONF_DIR/slaves"', shell=True)

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

cherrypy.quickstart(ScriptRunner(), '/domain-names/', conf)
