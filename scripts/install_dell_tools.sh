#!/bin/bash

# I got tired of having to look this up every single time
# mainly for 16.04, but I'll expand it if needed

echo "installing the dell tools"

echo 'deb http://linux.dell.com/repo/community/openmanage/911/xenial xenial main' | sudo tee -a /etc/apt/sources.list.d/linux.dell.com.sources.list 
gpg --keyserver pool.sks-keyservers.net --recv-key 1285491434D8786F 
gpg -a --export 1285491434D8786F | sudo apt-key add - 
apt update
apt install -y libxslt-dev srvadmin-all 