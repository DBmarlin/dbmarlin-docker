#!/bin/bash
set -e

echo "Starting DBmarlin upgrade init"

mkdir -p /opt/dbmarlin/.preserved

cp -p /opt/dbmarlin/.htpasswd /opt/dbmarlin/.preserved/ 2>/dev/null || true
cp -p /opt/dbmarlin/auth.conf /opt/dbmarlin/.preserved/ 2>/dev/null || true
cp -p /opt/dbmarlin/ssl.conf /opt/dbmarlin/.preserved/ 2>/dev/null || true

cp -r /dbmarlin-install/dbmarlin/* /opt/dbmarlin/

cp -p /opt/dbmarlin/.preserved/.htpasswd /opt/dbmarlin/ 2>/dev/null || true
cp -p /opt/dbmarlin/.preserved/auth.conf /opt/dbmarlin/ 2>/dev/null || true
cp -p /opt/dbmarlin/.preserved/ssl.conf /opt/dbmarlin/ 2>/dev/null || true

echo "DBmarlin init complete"
