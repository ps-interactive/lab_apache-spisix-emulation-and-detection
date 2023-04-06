#!/usr/bin/bash
export _sites_enabled="/etc/apache2/sites-enabled";
export _sites_available="/etc/apache2/sites-available";
export _mods_enabled="/etc/apache2/mods-enabled";
export _mods_available="/etc/apache2/mods-available";
export _apt_manifest="/tmp/installed-packages.log";
export _debug_logfile="/tmp/debug.log";
export _setup_logfile="/tmp/setup.log";
export SETUP_MODE="sandbox";
export DEBUG_MODE="debug";
declare -a _docker_repo_dependencies=(
  "apt-transport-https"
  "ca-certificates"
  "curl"
  "software-properties-common"
);
declare -a _main_dependencies=(
  "net-tools"
  "jq"
  "docker"
  "docker.io"
  "docker-compose"
  "apache2"
  "libapache2-mod-security2"
);

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

function initializeSetup()  {
  logDebug "Running ${FUNCNAME[0]}";

  logDebug "Updating APT repository";
  apt update &>>${_debug_logfile};
  logDebug "Generating list of packages";
  apt list > ${_apt_manifest};

  logDebug "Installing test environment dependencies";
  for _dependency in ${_docker_repo_dependencies[@]}; do
      apt install ${_dependency} -y &>>${_debug_logfile};
  done;

  logDebug "Adding Docker archive to sources";
  if (! test -f "/usr/share/keyrings/docker-archive-keyring.gpg"); then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg|
      gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
      &>>${_debug_logfile};
    echo "deb [arch=$(dpkg --print-architecture) \
    signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable"|sed "s/    //"|tr -d "\n"|
        tee /etc/apt/sources.list.d/docker.list &>/dev/null;
    logDebug "Updating APT with Docker repository";
    apt update &>>${_debug_logfile};
  fi;

  logDebug "Installing lab dependencies";
  for _dependency in ${_main_dependencies[@]}; do
      apt install ${_dependency} -y &>>${_debug_logfile};
  done;

  logDebug "${FUNCNAME[0]} complete";
  return 0;
}

function setupDocker() {
  logDebug "Running ${FUNCNAME[0]}";

  if (test "${1}"); then
    logDebug "Enabling Docker with proxy settings";
    mkdir -p /etc/systemd/system/docker.service.d;
    cat << EOF >> /etc/systemd/system/docker.service.d/proxy.conf
[Service]
Environment="HTTP_PROXY=${1}"
Environment="HTTPS_PROXY=${1}"
Environment="NO_PROXY=localhost,127.0.0.1,::1"
EOF
    logDebug "Reloading Docker daemon";
    systemctl daemon-reload &>>${_debug_logfile};
    systemctl restart docker &>>${_debug_logfile};
  fi;
  
  logDebug "Initializing Docker instance";
  cd /opt/CVE-2022-24112-Lab/docker-files
  docker-compose -p docker-apisix up -d &>>${_debug_logfile};

  logDebug "${FUNCNAME[0]} complete";
  return 0;
}

function setupApache() {
  logDebug "Running ${FUNCNAME[0]}";

  logMessage "Configuring Apache service";
  systemctl stop apache2 &>>${_debug_logfile};

  logDebug "Backing up original Apache configuration files";
  for _file in "apache2.conf" "ports.conf"; do
    cp "/etc/apache2/${_file}" "/etc/apache2/${_file}.orig";
  done;

  logDebug "Creating ports.conf configuration file for HTTP only";
  cat << EOF > /etc/apache2/ports.conf
Listen 0.0.0.0:80
EOF

  logDebug "Creating apache2.conf configuration file";
  cat << EOF > /etc/apache2/apache2.conf
# DEFAULT VALUES
DefaultRuntimeDir \${APACHE_RUN_DIR}
PidFile \${APACHE_PID_FILE}
Timeout 300
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5
HostnameLookups Off
# PROCESS CONTEXT
User \${APACHE_RUN_USER}
Group \${APACHE_RUN_GROUP}
# ERROR LOG LOCATION AND LEVEL
ErrorLog \${APACHE_LOG_DIR}/error.log
LogLevel warn
# MODULES INCLUDED
IncludeOptional mods-enabled/*.load
IncludeOptional mods-enabled/*.conf
# VIRTUAL HOST SETTINGS
Include ports.conf
<Directory />
	Options FollowSymLinks
	AllowOverride None
	Require all denied
</Directory>
<Directory /usr/share>
	AllowOverride None
	Require all granted
</Directory>
<Directory /var/www/>
	Options Indexes FollowSymLinks
	AllowOverride None
	Require all granted
</Directory>
AccessFileName .htaccess
<FilesMatch "^\.ht">
	Require all denied
</FilesMatch>
# LOG FORMAT SETTINGS
LogFormat "%v:%p %h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" vhost_combined
LogFormat "%h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" combined
LogFormat "%h %l %u %t \"%r\" %>s %O" common
LogFormat "%{Referer}i -> %U" referer
LogFormat "%{User-agent}i" agent
# INCLUDE CONFIGURATION AND SITE FILES
IncludeOptional conf-enabled/*.conf
IncludeOptional sites-enabled/*.conf
EOF

  logDebug "Creating apache-www.conf configuration file and symlink";
  cat << EOF > ${_sites_available}/apache-www.conf
<VirtualHost 0.0.0.0:80>
    ## MAIN SETTINGS:
    ServerAdmin admin@$(hostname)
    ErrorLog /var/log/apache2/error.log
    CustomLog /var/log/apache2/access.log combined
    ServerName localhost
    DocumentRoot /var/www/html/
    RewriteEngine On
    SSLProxyEngine On
    SSLEngine off
    SSLProxyCheckPeerCN Off
    SSLProxyVerify none
    SSLProxyCheckPeerName off
    SSLProxyCheckPeerExpire off
    ## 1 DETECTION SETTINGS:
#   ForensicLog /var/log/apache2/forensic.log
#   SecRuleEngine DetectionOnly
#    SecRule REQUEST_URI "@contains batch-requests" \\
#     "id:'2022241122',phase:2,t:none,log,allow,pass,msg:'CVE-2022-24112 - detected',chain"
#    SecRule REQUEST_HEADERS:X-API-KEY "edd1c9f034335f136f87ad84b625c8f1" "t:lowercase,chain"
#    SecRule REQUEST_HEADERS:Content-Type "application/json"
    ## 2 PREVENTION SETTINGS:
#   SecRule REQUEST_URI "@contains batch-requests" \\
#      "id:'2022241122',phase:2,t:none,log,deny,status:403,msg:'CVE-2022-24112 - prevented',chain"
#    SecRule REQUEST_HEADERS:X-API-KEY "edd1c9f034335f136f87ad84b625c8f1" "t:lowercase,chain"
#    SecRule REQUEST_HEADERS:Content-Type "application/json"
    # MAIN SETTINGS:
    RewriteRule ^(.*) http://127.0.0.1:9080/\$1 [NC,L,P]
</VirtualHost>
EOF
  for _conf in $(find ${_sites_enabled}/*conf); do
    unlink ${_conf} &>>${_debug_logfile};
  done;
  ln -s ${_sites_available}/apache-www.conf \
    ${_sites_enabled}/apache-www.conf;

  logDebug "Enabling modsecurity recommended configuration file";
  test -f /etc/modsecurity/modsecurity.conf-recommended && \
  cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf;

  logDebug "Backing up configuration file";
  test -f ${_mods_enabled}/security2.conf && \
  cp ${_mods_enabled}/security2.conf ${_mods_available}/security2.conf.orig;

  logDebug "Creating new ModSecurity mod-configuration file";
  cat << EOF > ${_mods_available}/security2.conf
<IfModule security2_module>
  SecDataDir /var/cache/modsecurity
  IncludeOptional /etc/modsecurity/*.conf
</IfModule>
EOF

  logDebug "Enabling Apache modules";
  a2enmod security2 &>>${_debug_logfile};
  a2enmod proxy rewrite &>>${_debug_logfile};
  a2enmod proxy proxy_http &>>${_debug_logfile};
  a2enmod ssl &>>${_debug_logfile};

  logDebug "Enabling HTTP service";
  systemctl start apache2 &>>${_debug_logfile};
  systemctl enable apache2 &>>${_debug_logfile};
  logDebug "${FUNCNAME[0]} complete";
  return 0;
}

function runSetup() {
  logMessage "Running lab setup";

  if (! isSudo); then
    logMessage "Root privileges required";
    return 1;
  fi;

  if [[ "$SETUP_MODE" == "test" ]]; then
      initializeSetup;
  fi;

  logMessage "Setting up Docker instance";
  if (! setupDocker ${1}); then
    logMessage "Failed to setup Docker instance";
    return 1;
  fi;

  logMessage "Setting up Apache proxy";
  if (! setupApache); then
    logMessage "Failed to setup Apache proxy";
    return 1;
  fi;

  logMessage "Setup complete. Debug log located: ${_debug_logfile}";
  touch /tmp/.setup-complete
  return 0;
}

runSetup ${1} >> ${_setup_logfile}
