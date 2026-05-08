#!/usr/bin/env python3
# Sailifish Containers qxcompositor wrapper

import os
import subprocess

def new(user, display_id, user_uid, path, screen_orientation):
    """ Create qxcompositor's display """
    scripts_path = "%s/scripts" % str(path)
    cmd = 'export XDG_RUNTIME_DIR=/run/user/' + str(user_uid) + ' && %s/host/new_display.sh %s %s %s' % (scripts_path, display_id, user_uid, screen_orientation)
    proc = subprocess.Popen(['su', user, '-c', cmd], stdout=open('/tmp/qx_stdout.log','w'), stderr=open('/tmp/qx_stderr.log','w'), shell=False)
    return True

def kill(qxcompositor_pid):
    """ Kill qxcompositor process """
    os.kill(qxcompositor_pid)
    return True