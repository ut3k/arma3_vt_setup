#!/bin/bash
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
  ssh-keygen -A
fi
/usr/sbin/sshd -D -p 8873
