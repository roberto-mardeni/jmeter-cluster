#!/bin/bash

# The MIT License (MIT)
#
# Copyright (c) 2015 Microsoft Azure
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Hans Krijger (MSFT)
#

help()
{
    echo "This script installs JMeter on Ubuntu"
    echo "Parameters:"
    echo "  -h                view this help content"
    echo "  -v                JMeter version to install"
    echo "  -m                install as a master node"
    echo "  -r <hosts>        set remote hosts (master only)"
    echo "  -j <jarball>      location of the jarball to download and unzip"
}

log()
{
    echo "$1"
}

error()
{
    echo "$1" >&2
    exit 1
}

if [ "${UID}" -ne 0 ];
then
    error "Script executed without root permissions"
fi

# script parameters
IS_MASTER=0
REMOTE_HOSTS=""
JMETER_VERSION="5.1.1"
JMETER_PLUGINS_VERSION="1.3.1"

while getopts :hmr:j: optname; do
  log "Option $optname set with value ${OPTARG}"
  case $optname in
    h) # show help
      help
      exit 2
      ;;
    m) # setup as master
      IS_MASTER=1
      ;;
    r) # provide remote hosts
      REMOTE_RANGE=${OPTARG}
      ;;
    j) # provide jarball
      JARBALL=${OPTARG}
      ;;
    \?) # unrecognized option - show help
      help
      error "Option ${OPTARG} not allowed."
      ;;
  esac
done

expand_ip_range() {
    IFS='-' read -a HOST_IPS <<< "$1"
    declare -a MY_IPS=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
    declare -a EXPAND_STATICIP_RANGE_RESULTS=()
    for (( n=0 ; n<("${HOST_IPS[1]}"+0) ; n++))
    do
        HOST="${HOST_IPS[0]}${n}"
        if ! [[ "${MY_IPS[@]}" =~ "${HOST}" ]]; then
            EXPAND_STATICIP_RANGE_RESULTS+=($HOST)
        fi
    done
    echo "${EXPAND_STATICIP_RANGE_RESULTS[@]}"
}

install_java()
{
    # http://ubuntuhandbook.org/index.php/2018/11/how-to-install-oracle-java-11-in-ubuntu-18-04-18-10/
    log "Installing Java 11"
    add-apt-repository -y ppa:linuxuprising/java
    apt-get -y update
    # https://stackoverflow.com/questions/19275856/auto-yes-to-the-license-agreement-on-sudo-apt-get-y-install-oracle-java7-instal
    echo debconf shared/accepted-oracle-license-v1-2 select true | sudo debconf-set-selections
    echo debconf shared/accepted-oracle-license-v1-2 seen true | sudo debconf-set-selections
    apt-get -y install oracle-java11-installer
    apt-get -y install oracle-java11-set-default
}

install_jmeter_service()
{
    keytool -genkey -keyalg RSA -alias rmi -keystore rmi_keystore.jks -storepass changeit -validity 7 -keysize 2048 -dname "CN=JMeter Cluster, OU=Test, O=Test, L=Miami, ST=FL, C=US" -keypass changeit "$@"

    cp rmi_keystore.jks /opt/jmeter/apache-jmeter-${JMETER_VERSION}/bin/rmi_keystore.jks

    cat << EOF > /etc/systemd/system/jmeter.service
[Unit]
Description=JMeter Server
After=network.target

[Service]
ExecStart=/opt/jmeter/apache-jmeter-${JMETER_VERSION}/bin/jmeter-server
User=sysadmin
WorkingDirectory=/opt/jmeter/apache-jmeter-${JMETER_VERSION}/bin
KillMode=process
KillSignal=SIGTERM
TimeoutStopSec=5min

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable jmeter.service
    systemctl start jmeter.service
    systemctl --no-pager status jmeter.service
}

update_config_sub()
{
    mv /opt/jmeter/apache-jmeter-${JMETER_VERSION}/bin/jmeter.properties /opt/jmeter/apache-jmeter-${JMETER_VERSION}/bin/jmeter.properties.bak
    cat /opt/jmeter/apache-jmeter-${JMETER_VERSION}/bin/jmeter.properties.bak | sed "s|#client.rmi.localport=0|client.rmi.localport=4441|" | sed "s|#server.rmi.localport=4000|server.rmi.localport=4440|" > /opt/jmeter/apache-jmeter-${JMETER_VERSION}/bin/jmeter.properties 
}

update_config_boss()
{
    mv /opt/jmeter/apache-jmeter-${JMETER_VERSION}/bin/jmeter.properties /opt/jmeter/apache-jmeter-${JMETER_VERSION}/bin/jmeter.properties.bak
    cat /opt/jmeter/apache-jmeter-${JMETER_VERSION}/bin/jmeter.properties.bak | sed "s|#client.rmi.localport=0|client.rmi.localport=4440|" | sed "s|remote_hosts=127.0.0.1|remote_hosts=${REMOTE_HOSTS}|" > /opt/jmeter/apache-jmeter-${JMETER_VERSION}/bin/jmeter.properties 
}

install_jmeter()
{
    log "Installing JMeter"
    apt-get -y install unzip 
    
    mkdir -p /opt/jmeter
    wget -O jmeter.zip http://archive.apache.org/dist/jmeter/binaries/apache-jmeter-${JMETER_VERSION}.zip
    wget -O JMeterPlugins-Standard.zip http://jmeter-plugins.org/downloads/file/JMeterPlugins-Standard-${JMETER_PLUGINS_VERSION}.zip
    wget -O JMeterPlugins-Extras.zip http://jmeter-plugins.org/downloads/file/JMeterPlugins-Extras-${JMETER_PLUGINS_VERSION}.zip
    wget -O JMeterPlugins-ExtrasLibs.zip http://jmeter-plugins.org/downloads/file/JMeterPlugins-ExtrasLibs-${JMETER_PLUGINS_VERSION}.zip
    wget -O JMeterPlugins-WebDriver.zip http://jmeter-plugins.org/downloads/file/JMeterPlugins-WebDriver-${JMETER_PLUGINS_VERSION}.zip
    
    log "unzipping jmeter"
    unzip -q jmeter.zip -d /opt/jmeter/
    
    log "unzipping plugins"
    unzip -qo JMeterPlugins-Standard.zip -d /opt/jmeter/apache-jmeter-${JMETER_VERSION}/
    unzip -qo JMeterPlugins-Extras.zip -d /opt/jmeter/apache-jmeter-${JMETER_VERSION}/
    unzip -qo JMeterPlugins-ExtrasLibs.zip -d /opt/jmeter/apache-jmeter-${JMETER_VERSION}/
    unzip -qo JMeterPlugins-WebDriver.zip -d /opt/jmeter/apache-jmeter-${JMETER_VERSION}/
     
    chmod u+x /opt/jmeter/apache-jmeter-${JMETER_VERSION}/bin/jmeter-server
    chmod u+x /opt/jmeter/apache-jmeter-${JMETER_VERSION}/bin/jmeter

    if [ ${JARBALL} ];
    then
        log "installing jarball"
        wget -O jarball.zip ${JARBALL}
        unzip -q jarball.zip -d /opt/jmeter/apache-jmeter-${JMETER_VERSION}/lib/junit/
    fi
    
    if [ ${IS_MASTER} -ne 1 ]; 
    then
        log "setting up sub node"
        iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 4441 -j ACCEPT
        
        update_config_sub
        install_jmeter_service
    else
        log "setting up boss node"
        iptables -A INPUT -p tcp --match multiport --dports 4440:4445 -j ACCEPT
        iptables -A OUTPUT -p tcp --match multiport --dports 4440:4445 -j ACCEPT
    
        update_config_boss
    fi
    
    groupadd -g 999 jmeter
    useradd -u 999 -g 999 jmeter
    chown -R jmeter: /opt/jmeter
}

if [ ${REMOTE_RANGE} ];
then
    S=$(expand_ip_range "$REMOTE_RANGE")
    REMOTE_HOSTS="${S// /,}"
    log "using remote hosts ${REMOTE_HOSTS}"
fi

install_java
install_jmeter

# remove any zip files downloaded
rm -f *.zip

log "script complete"