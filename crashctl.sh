#!/bin/bash
set -o errexit -o nounset -o pipefail
export LC_ALL=C
function -h {
  cat <<USAGE
   USAGE: A tool to diagnose system reboots

   -i / --id      Show boot ID
   -n / --last    Last N messages of system logs to check (default: 20)
   -u / --utc     Show timestamps in UTC
   -v / --verbose Show timestamps in UTC

      $(basename "$0")
USAGE
}; function --help { -h ;}

function msg { out "$*" >&1 ;}
function out { printf '%s\n' "$*" ;}
function err { local x=$? ; msg "$*" ; return $(( $x == 0 ? 1 : $x )) ;}
function banner { printf '%-20s: %s\n' "$1" "$2" ;}

function kernel_version {
  uname -v -r
}

function current_boot {
  cat /proc/sys/kernel/random/boot_id
}

function system_start {
  date -d"$(uptime -s)"
}

function parse_uptime {
  local res="$(uptime | grep -oP 'up\s([0-9a-z\:\s]+)')"
  echo $res
}

function os_version {
  lsb_release -d | cut -f2
}

function running_processes {
  ps ax | wc -l | tr -d ' '
}

function install_date {
  # try checking root filesystem install date
  local installed=$(stat / | grep "Birth" | sed 's/Birth: //g' | cut -b 2-11)
  if [[ "${installed}" == "-" ]]; then
    local fs=$(df / | tail -1 | cut -f1 -d' ')
    installed="$(tune2fs -l ${fs} | grep 'Filesystem created' | cut -d':' -f 2- | awk '{$1=$1};1')"
  fi
  date -d"${installed}"
}

# Load scaled to number of CPU threads
function print_load {
  local load=($(cat /proc/loadavg | cut -d' ' -f 1-3))
  local threads=$(nproc)
  local scload=""
  for avg in ${load[@]}; do
    scload+=$(printf '%.2f ' $(echo "scale=2; $avg / $threads" | bc))
  done
  echo "${scload}"
}

# Add dashes to UUID
function format_uuid {
  local uuid="$1"
  # simply cut out bash substrings, no validation needed
  printf '%s-%s-%s-%s-%s' "${uuid:0:8}" "${uuid:8:4}" "${uuid:12:4}" "${uuid:16:4}" "${uuid:20:12}"
}

# Check last N lines of kernel log to check whether system was rebooted
function check_rebooted {
  local out="$(journalctl -k -b $1 -n $2 -o cat | grep 'SIGTERM')"
  local res=""
  if [[ ! -z "${out}" ]]; then
    res="reboot (SIGTERM)"
  else
    out="$(journalctl -u systemd-logind -b $1 -n $2 | grep 'Power key pressed')"
    if [[ ! -z "${out}" ]]; then
      res="Power key pressed at $(echo "${out}" | tail -n 1 | cut -d ' ' -f 1-3)"
    else
      res="CRASH?"
    fi
  fi
  echo "${res}"
}

# Expects two timestamps e.g.:
# "2022-12-05 21:40:40"
# "2022-12-06 11:40:40"
function date_diff {
  local start_ts=$(date -d "$1" '+%s')
  local end_ts=$(date -d "$2" '+%s')

  local secs=$(( $end_ts - $start_ts ))
  printf '%dd %02d:%02d:%02d\n' $((secs/86400)) $((secs%86400/3600)) $((secs%3600/60)) \
  $((secs%60))
}

function check_kdump {
  local kdump=$(which kdump-config)
  if [[ ! -z "${kdump}" ]]; then
    kdump-config status
  else
    err "kdump-tools not installed. Try: apt install kdump-tools"
  fi
}

function main {
  local verbose=false
  local utc=false
  local last_lines=20
  local show_id=false
  local boots_only=false
  while [[ $# -gt 0 ]]
  do
    case "$1" in
      -b|--boots)           boots_only=true; shift 1 ;;
      -i|--id)              show_id=true; shift 1 ;;
      -n|--last)            last_lines="$2"; shift 2 ;;
      -v|--verbose)         verbose=true; shift 1 ;;
      -u|--utc)             utc=true; shift 1 ;;
      *)                    err 'Argument error. Please see help: -h' ;;
    esac
  done

  if [[ $verbose == true ]]; then
    set -x
  fi

  local curr_boot="$(current_boot)"

  if [[ ${boots_only} == false ]]; then
    banner "Distribution" "$(os_version)"
    banner "Kernel" "$(kernel_version)"
    banner "Current boot" "${curr_boot}"
    banner "Scaled load" "$(print_load)"
    banner "System installed" "$(install_date)"
    banner "System started" "$(system_start)"
    banner "Uptime" "$(parse_uptime)"
    banner "Running processes" "$(running_processes)"
    banner "kdump" "$(check_kdump)"
  fi

  local second_col="First message"
  local col2size=25
  if [[ ${show_id} == true ]]; then
    second_col="UUID"
    col2size=38
  fi
  local line_format="%-4s %-${col2size}s %-24s %-12s %s\n"
  printf "${line_format}" "Boot" "${second_col}" "Last message" "Uptime" "Reboot/Crash"
  printf -- '-%.0s' {1..85}
  printf '\n'

  local cmd="journalctl --list-boots"
  if [[ $utc == true ]]; then
    cmd+=" --utc"
  fi
  while read line; do
    local ary=($line)
    local boot_id=${ary[0]}
    local uuid="$(format_uuid ${ary[1]})"

    local rebooted=""
    if [[ "${uuid}" == "${curr_boot}" ]]; then
      rebooted="running"
    else
      rebooted="$(check_rebooted "${boot_id}" "${last_lines}")"
    fi
    local first_msg="${ary[3]} ${ary[4]} ${ary[5]:0:3}"
    local last_msg="${ary[6]} ${ary[7]}"
    if [[ ${show_id} == true ]]; then
      second_col="${uuid}"
    else
      second_col="${first_msg}"
    fi

    local up="$(date_diff "${first_msg}" "${last_msg}")"
    printf "${line_format}" "${boot_id}" "${second_col}" "${last_msg} ${ary[8]}" "${up}" "${rebooted}"
  done < <(eval "${cmd}")
}

if [[ ${1:-} ]] && declare -F | cut -d' ' -f3 | fgrep -qx -- "${1:-}"
then
  case "$1" in
    -h|--help) : ;;
    *) ;;
  esac
  "$@"
else
  main "$@"
fi

