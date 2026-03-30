#!/bin/bash

CONFIG="./config/config.py"
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null)

get_port() {
    grep "^PORT" "$CONFIG" | grep -o '[0-9]*'
}

get_domain() {
    grep "^TLS_DOMAIN" "$CONFIG" | cut -d'"' -f2
}

tg_link() {
    local secret=$1
    local port=$(get_port)
    local domain=$(get_domain)
    local domain_hex=$(python3 -c "print('$domain'.encode().hex())")
    local tg_secret="ee${secret}${domain_hex}"
    echo "tg://proxy?server=${SERVER_IP}&port=${port}&secret=${tg_secret}"
}

# OSC 8 clickable hyperlink (supported in Windows Terminal, iTerm2, etc.)
hyperlink() {
    local url=$1 text=$2
    printf '\e]8;;%s\e\\%s\e]8;;\e\\' "$url" "$text"
}

random_secret() {
    openssl rand -hex 16
}

reload() {
    docker restart mtproto
}

case $1 in
  add)
    [[ -z $2 ]] && echo "Usage: $0 add <user> [user2...]" && exit 1
    shift
    for user in "$@"; do
      if grep -q "\"${user}\"," "$CONFIG"; then
        echo "User $user already exists, skipping"
        continue
      fi
      secret=$(random_secret)
      sed -i "/# managed by manage.sh/a\\    \"${secret}\": \"${user}\"," "$CONFIG"
      url=$(tg_link "$secret")
      echo ""
      echo "  User:    $user"
      echo "  Secret:  $secret"
      echo "  TG link: $(hyperlink "$url" "$url")"
      echo ""
    done
    reload
    ;;
  remove)
    [[ -z $2 ]] && echo "Usage: $0 remove <user>" && exit 1
    grep -q "\"$2\"," "$CONFIG" || { echo "User $2 not found"; exit 1; }
    sed -i "/\"$2\",/d" "$CONFIG"
    reload
    echo "Removed $2"
    ;;
  list)
    echo "Users:"
    grep -v "# managed" "$CONFIG" | grep '":' | awk -F'"' '{print "  " $4}'
    ;;
  link)
    [[ -z $2 ]] && echo "Usage: $0 link <user> [user2...|all]" && exit 1
    shift
    if [[ $1 == "all" ]]; then
      set -- $(grep -v "# managed" "$CONFIG" | grep '":' | awk -F'"' '{print $4}')
    fi
    for user in "$@"; do
      secret=$(grep "\"${user}\"," "$CONFIG" | cut -d'"' -f2)
      if [[ -z $secret ]]; then
        echo "User $user not found"
        continue
      fi
      url=$(tg_link "$secret")
      echo "$user: $(hyperlink "$url" "$url")"
    done
    ;;
  *)
    echo "Usage: $0 {add <user> [user2...]|remove <user>|list|link <user> [user2...|all]}"
    ;;
esac
