#!/bin/bash

USERS_FILE="./config/users.cfg"
SOCKS5_PORT=1080
# Auto-detect public IP or set manually:
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null)

tg_link() {
    local user=$1 pass=$2
    echo "tg://socks?server=${SERVER_IP}&port=${SOCKS5_PORT}&user=${user}&pass=${pass}"
}

# OSC 8 clickable hyperlink (supported in Windows Terminal, iTerm2, etc.)
hyperlink() {
    local url=$1 text=$2
    printf '\e]8;;%s\e\\%s\e]8;;\e\\' "$url" "$text"
}

random_pass() {
    tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 16
}

case $1 in
  add)
    [[ -z $2 ]] && echo "Usage: $0 add <user> [pass]" && exit 1
    shift
    for user in "$@"; do
      if grep -q "^users $user:" "$USERS_FILE"; then
        echo "User $user already exists, skipping"
        continue
      fi
      pass=$(random_pass)
      echo "users $user:CL:$pass" >> "$USERS_FILE"
      echo ""
      echo "  User:     $user"
      echo "  Password: $pass"
      url=$(tg_link $user $pass)
      echo "  TG link:  $(hyperlink "$url" "$url")"
      echo ""
    done
    docker kill --signal=HUP 3proxy
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
    [[ -z $2 ]] && echo "Usage: $0 link <user> [user2...|all]" && exit 1
    shift
    if [[ $1 == "all" ]]; then
      set -- $(grep "^users" "$USERS_FILE" | cut -d: -f1 | sed 's/users //')
    fi
    for user in "$@"; do
      pass=$(grep "^users $user:" "$USERS_FILE" | cut -d: -f3)
      if [[ -z $pass ]]; then
        echo "User $user not found"
        continue
      fi
      url=$(tg_link $user $pass)
      echo "$user: $(hyperlink "$url" "$url")"
    done
    ;;
  *)
    echo "Usage: $0 {add <user> [user2...]|remove <user>|list|link <user> [user2...|all]}"
    ;;
esac
