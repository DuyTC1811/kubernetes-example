#!/bin/bash
set -euo pipefail

apt update -y
apt install git curl sudo -y
usermod -aG sudo debian