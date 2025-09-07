#!/bin/bash

os_family=$(uname)

get_minutes_from_hhmm() {
  IFS=":" read -r hours minutes <<< "$1"
  echo $((10#$hours * 60 + 10#$minutes))
}

get_minutes_from_parts() {
  local total=0
  local regex='([0-9]+) (day|days|hour|hours|minute|minutes)'
  while [[ $1 =~ $regex ]]; do
    num=${BASH_REMATCH[1]}
    unit=${BASH_REMATCH[2]}
    case "$unit" in
      day|days) total=$((total + num * 1440)) ;;
      hour|hours) total=$((total + num * 60)) ;;
      minute|minutes) total=$((total + num)) ;;
    esac
    # Remove the matched part and continue
    shift_text="${BASH_REMATCH[0]}"
    set -- "${1#*$shift_text}"
  done
  echo $total
}

case "$os_family" in
  Linux)
    if command -v uptime &> /dev/null; then
      up=$(uptime -p 2>/dev/null)
      if [[ $? -eq 0 && -n "$up" ]]; then
        up_cleaned="${up#up }"
        echo "$(get_minutes_from_parts "$up_cleaned")"
        exit 0
      fi
    fi

    # Fallback: parse raw uptime
    up=$(uptime | sed 's/.*up //' | awk -F',' '{print $1}' | xargs)
    if [[ "$up" =~ [0-9]+:[0-9]+ ]]; then
      echo "$(get_minutes_from_hhmm "$up")"
    else
      echo "$(get_minutes_from_parts "$up")"
    fi
    ;;

  SunOS|AIX)
    up=$(uptime | sed 's/.*up //' | awk -F',' '{print $1}' | xargs)
    if [[ "$up" =~ [0-9]+:[0-9]+ ]]; then
      echo "$(get_minutes_from_hhmm "$up")"
    else
      echo "$(get_minutes_from_parts "$up")"
    fi
    ;;

  *)
    echo "0"
    exit 1
    ;;
esac
