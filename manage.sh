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
  stats)
    today=$(date +%Y.%m.%d)
    logfile="./logs/3proxy.log.$today"
    [[ ! -f "$logfile" ]] && logfile=$(ls -t ./logs/3proxy.log.* 2>/dev/null | head -1)
    [[ -z "$logfile" ]] && echo "No log files found" && exit 1
    echo "Stats from $(basename $logfile):"
    echo ""
    # Pass 1: total connections per user
    awk '/^- \+_L/ && $6 != "-" { conns[$6]++ }
      END { for (u in conns) print u, conns[u] }' "$logfile" > /tmp/3proxy_totals
    # Pass 2: sweep-line peak simultaneous connections
    # Log entries are written at connection END; $3=end time, $11=duration(sec)
    # So start = end - duration. Emit +1 at start, -1 at end, sort, sweep.
    awk '/^- \+_L/ && $6 != "-" {
      user=$6
      split($3, t, ":")
      end_sec = t[1]*3600 + t[2]*60 + int(t[3])
      start_sec = end_sec - int($11)
      if (start_sec < 0) start_sec = 0
      printf "%09d -1 %s\n", end_sec, user
      printf "%09d +1 %s\n", start_sec, user
    }' "$logfile" | sort | \
    awk '{
      delta = ($2 == "+1") ? 1 : -1
      count[$3] += delta
      if (count[$3] > peak[$3]) peak[$3] = count[$3]
    }
    END { for (u in peak) print u, peak[u] }' > /tmp/3proxy_peaks
    # Merge and display, sorted by total conns desc
    awk 'NR==FNR { total[$1]=$2; next } { print total[$1], $2, $1 }' \
      /tmp/3proxy_totals /tmp/3proxy_peaks | sort -rn | \
    awk 'BEGIN { printf "%-20s %8s %12s\n", "User", "Conns", "Peak Simult." }
         { printf "%-20s %8d %12d\n", $3, $1, $2 }'
    rm -f /tmp/3proxy_totals /tmp/3proxy_peaks
    ;;
  *)
    echo "Usage: $0 {add <user> [user2...]|remove <user>|list|link <user> [user2...|all]|stats}"
    ;;
esac
