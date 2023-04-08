#!/usr/bin/bash
export _debug_logfile="/tmp/debug.log";
export _setup_logfile="/tmp/setup.log";
export SETUP_MODE="sandbox";
export DEBUG_MODE="debug";

function isSudo(){
  if [[ "$EUID" -ne 0 ]]; then
    return 1;
  fi;
  return 0;
}

function logDebug() {
  echo "[*] DEBUG: $(date) ${@}">>${_debug_logfile};
  if [[ "$DEBUG_MODE" == "debug" ]]; then
      tail -1 ${_debug_logfile};
  fi;
}

function logMessage() {
  echo "[+] INFO: $(date) ${@}">>${_debug_logfile};
  tail -1 ${_debug_logfile};
}

function setupLearnerFiles() {
  logDebug "Running ${FUNCNAME[0]}";
  logDebug "Copying learner files";
  test -d /home/pslearner || (logDebug "Missing home folder" && return 1);

  logDebug "Creating symlink to commands directory";
  ln -s /opt/CVE-2022-24112-Lab/client-commands /home/pslearner/commands;
  rm -rf /opt/CVE-2022-24112-Lab/server-commands;
  rm -rf /opt/CVE-2022-24112-Lab/docker-files;
  rm -rf /opt/CVE-2022-24112-Lab/apache-files;
  rm /opt/CVE-2022-24112-Lab/setup.sh;

  logDebug "Setting read-execute permissions";
  chmod -R a+rx /home/pslearner/commands;
  logDebug "Setting user and group ownership";
  chown -R pslearner:pslearner /home/pslearner;
  logDebug "Enabling immutable bit for commands";
  for _file in $(find /home/pslearner/commands -type f -name "*.sh"); do
    chattr +i ${_file};
  done;
  logDebug "${FUNCNAME[0]} complete";
  return 0;
}

function runSetup() {
  logMessage "Running lab setup";

  if (! isSudo); then
    logMessage "Root privileges required";
    return 1;
  fi;

  logMessage "Setting up learner files";
  if (! setupLearnerFiles); then
    logMessage "Failed to setup learner files";
    return 1;
  fi;

  logMessage "Setup complete. Debug log located: ${_debug_logfile}";
  rm /opt/CVE-2022-24112-Lab/setup-learner.sh;
  truncate -s0 ~/.bash_history;
  truncate -s0 /home/ubuntu/.bash_history;
  touch /tmp/.setup-complete;
  history -c;
  return 0;
}

test -f /tmp/.setup-complete || runSetup ${1} >> ${_setup_logfile};