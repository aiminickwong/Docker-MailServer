#!/bin/bash

os=`cat /etc/issue |grep -c CentOS`
if [ $os = "0" ]; then
    echo "This script work only on CentOS. Exit."
    exit
fi
# ------------------------------
# Define some global variables.
# ------------------------------
tmprootdir="$(dirname $0)"
echo ${tmprootdir} | grep '^/' >/dev/null 2>&1
if [ X"$?" == X"0" ]; then
    export ROOTDIR="${tmprootdir}"
else
    export ROOTDIR="$(pwd)"
fi

cd ${ROOTDIR}

export CONF_DIR="${ROOTDIR}/conf"
export FUNCTIONS_DIR="${ROOTDIR}/functions"
export DIALOG_DIR="${ROOTDIR}/dialog"
export PKG_DIR="${ROOTDIR}/pkgs"
export SAMPLE_DIR="${ROOTDIR}/samples"
export TOOLS_DIR="${ROOTDIR}/tools"
export CERTIFICATES_DIR="${ROOTDIR}/certificates"


. ${ROOTDIR}/config
. ${CONF_DIR}/global
. ${CONF_DIR}/core

# Check downloaded packages, pkg repository.
[ -f ${STATUS_FILE} ] && . ${STATUS_FILE}
if [ X"${status_get_all}" != X"DONE" -a X"${CONFIGURATION_ONLY}" != X"YES" ]; then
    cd ${ROOTDIR}/pkgs/ && bash get_all.sh
    if [ X"$?" == X'0' ]; then
        cd ${ROOTDIR}
    else
        exit 255
    fi
fi

# --------------------------------------
# Check target platform and environment.
# --------------------------------------
# Required by OpenVZ:
# Make sure others can read-write /dev/null and /dev/*random, so that it won't
# interrupt iRedMail installation.
chmod go+rx /dev/null /dev/*random &>/dev/null

LOCAL_MYSQL_SERVER=""

check_env

if [ "$SQL_SERVER" = '127.0.0.1' ]; then
    USE_LOCAL_MYSQL_SERVER='YES'
else
    USE_LOCAL_MYSQL_SERVER='NO'
fi

# ------------------------------
# Import variables.
# ------------------------------
# Source 'conf/apache_php' first, other components need some variables
# defined in it.
. ${CONF_DIR}/apache_php
. ${CONF_DIR}/ldapd
. ${CONF_DIR}/mysql
. ${CONF_DIR}/postfix
. ${CONF_DIR}/policy_server
. ${CONF_DIR}/dovecot
. ${CONF_DIR}/amavisd
. ${CONF_DIR}/clamav
. ${CONF_DIR}/spamassassin
. ${CONF_DIR}/awstats
. ${CONF_DIR}/opendkim
. ${CONF_DIR}/fail2ban
. ${CONF_DIR}/server_api
. ${CONF_DIR}/spam_trainer

# ------------------------------
# Import functions.
# ------------------------------
# All packages.
. ${FUNCTIONS_DIR}/packages.sh


# User/Group: vmail. We will export vmail uid/gid here.
. ${FUNCTIONS_DIR}/system_accounts.sh
. ${FUNCTIONS_DIR}/apache_php.sh
. ${FUNCTIONS_DIR}/mysql.sh


# Switch backend
. ${FUNCTIONS_DIR}/backend.sh
. ${FUNCTIONS_DIR}/postfix.sh
. ${FUNCTIONS_DIR}/policy_server.sh
. ${FUNCTIONS_DIR}/dovecot.sh
. ${FUNCTIONS_DIR}/clamav.sh
. ${FUNCTIONS_DIR}/amavisd.sh
. ${FUNCTIONS_DIR}/spamassassin.sh
. ${FUNCTIONS_DIR}/awstats.sh
. ${FUNCTIONS_DIR}/opendkim.sh
. ${FUNCTIONS_DIR}/fail2ban.sh
. ${FUNCTIONS_DIR}/server_api.sh
. ${FUNCTIONS_DIR}/spam_trainer.sh
. ${FUNCTIONS_DIR}/optional_components.sh
. ${FUNCTIONS_DIR}/cleanup.sh

# ************************************************************************
# *************************** Script Main ********************************
# ************************************************************************

# Install all packages.
check_status_before_run install_all || (ECHO_ERROR "Package installation error, please check the output log." && exit 255)



echo -e '\n\n'
cat <<EOF

********************************************************************
* Start iRedMail Configurations
********************************************************************
EOF

# Create SSL/TLS cert file.
if [ ! -f ${SSL_CERT_FILE} -o ! -f ${SSL_KEY_FILE} -o ! -f ${SSL_CA_BUNDLE_FILE} ]; then
    check_status_before_run generate_ssl_keys
fi

# User/Group: vmail
check_status_before_run add_required_users

# Apache & PHP.
check_status_before_run apache_php_config

# Install & Config Backend: OpenLDAP or MySQL.n
check_status_before_run backend_install

# Postfix.
check_status_before_run postfix_config_basic && \
check_status_before_run postfix_config_virtual_host && \
check_status_before_run postfix_config_sasl && \
check_status_before_run postfix_config_tls

# Policy service for Postfix: Policyd.
check_status_before_run policy_server_config

# Dovecot.
check_status_before_run enable_dovecot

# ClamAV.
check_status_before_run clamav_config

# Amavisd-new.
check_status_before_run amavisd_config

# SpamAssassin.
check_status_before_run sa_config

# Optional components.
optional_components

# Cleanup.
check_status_before_run cleanup