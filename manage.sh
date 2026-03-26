#!/bin/bash

USERS_FILE="./config/users.cfg"
SOCKS5_PORT=1080
# Auto-detect public IP or set manually:
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null)

tg_link() {
    local user=$1 pass=$2
    echo "tg://socks?server=${SERVER_IP}&port=${SOCKS5_PORT}&user=${user}&pass=${pass}"
}

random_pass() {
    tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 16
}

case $1 in
  add)
    [[ -z $2 ]] && echo "Usage: $0 add <user> [pass]" && exit 1
    grep -q "^users $2:" "$USERS_FILE" && echo "User $2 already exists" && exit 1
    pass=${3:-$(random_pass)}
    echo "users $2:CL:$pass" >> "$USERS_FILE"
    docker kill --signal=HUP 3proxy
    echo ""
    echo "  User:     $2"
    echo "  Password: $pass"
    echo "  TG link:  $(tg_link $2 $pass)"
    echo ""
    ;;
  remove)
    [[ -z $2 ]] && echo "Usage: $0 remove <user>" && exit 1
    sed -i "/^users $2:/d" "$USERS_FILE"
    docker kill --signal=HUP 3proxy
    echo "Removed $2"
    ;;
  list)
    echo "Users:"
    grep "^users" "$USERS_FILE" | awk -F: '{print "  " $1}' | sed 's/users //'
    ;;
  link)
    [[ -z $2 ]] && echo "Usage: $0 link <user>" && exit 1
    pass=$(grep "^users $2:" "$USERS_FILE" | cut -d: -f3)
    [[ -z $pass ]] && echo "User $2 not found" && exit 1
    echo "$(tg_link $2 $pass)"
    ;;
  *)
    echo "Usage: $0 {add <user> [pass]|remove <user>|list|link <user>}"
    ;;
esac
