#!/bin/bash
set -o nounset -o pipefail
export LC_ALL=C
function -h {
  cat <<USAGE
   USAGE: A tool to diagnose system reboots

   -i / --id      Show boot ID
   -n / --last    Last N messages of system logs to check (default: 20)
   -u / --utc     Show timestamps in UTC
   -v / --verbose Print each executed command

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

function systemd_version {
  systemctl --version | head -n1 | awk '{print $2}'
}

function os_version {
  if [[ -f /etc/os-release ]]; then
    echo $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f 2 | tr -d '"')
  else
    local lsb=$(which lsb_release)
    if [[ ! -z "${lsb}" ]]; then
      echo $(lsb_release -d | cut -f2)
    fi
  fi
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
      local shutdown_date="$(echo "${out}" | tail -n 1 | cut -d ' ' -f 1-3)"
      local shutdown_ts=$(date -d"${shutdown_date}" '+%s')
      # shutdown should happen within 2 min
      if [[ ${shutdown_ts} -lt 120 ]]; then
        res="Power key pressed at ${shutdown_ts}"
      else
        res="Power key pressed, but ignored"
      fi
    else
      res="CRASH?"
    fi
  fi

  # Search for kernel bugs, crashes
  # check if journalctl compiled with grep functionality
  systemctl --version | grep "+PCRE2" > /dev/null
  if [[ $? -eq 0 ]]; then
    out="$(journalctl -k -b $1 -g 'Oops|BUG')"
  else
    out="$(journalctl -k -b $1 | grep -E 'Oops|BUG')"
  fi
  if [ ! -z "${out}" -a "${out}" != '-- No entries --' ]; then
    res+=" $(echo "${out}" | tail -n 1 | cut -d ' ' -f 1-3)"
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

# args:
# 1: date of last message
# 2: directory where crashlogs are being stored
# 3: cause of reboot
function check_crashlog {
  local lastmsg=$(date -d "$1" '+%Y%m%d%H%M')
  local crashlog="$2/${lastmsg}"
  if [[ -d "${crashlog}" ]]; then
    echo "kernel panic. see ${crashlog}"
  else
    echo $3
  fi
}

function main {
  local verbose=false
  local utc=false
  local last_lines=20
  local show_id=false
  local boots_only=false
  local crashdir="/var/crash"
  while [[ $# -gt 0 ]]
  do
    case "$1" in
      -b|--boots)           boots_only=true; shift 1 ;;
      -i|--id)              show_id=true; shift 1 ;;
      -n|--last)            last_lines="$2"; shift 2 ;;
      -c|--crashdir)        crashdir="$2"; shift 2 ;;
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
    banner "systemd version" "$(systemd_version)"
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
    # skip header (e.g. on systemd >= 252)
    if [[ "${line}" =~ ^[-0-9]+ ]]; then
      local ary=($line)
      local boot_id=${ary[0]}
      local uuid="$(format_uuid ${ary[1]})"
      local last_msg="${ary[6]} ${ary[7]} ${ary[8]}"

      local rebooted=""
      if [[ "${uuid}" == "${curr_boot}" ]]; then
        rebooted="running"
      else
        journalctl -b ${boot_id} -n 0 2> /dev/null 1> /dev/null
        if [[ $? -eq 1 ]]; then
          rebooted=$(journalctl -b ${boot_id} 2>&1) # journalctl reports error, show the error message
        else
          rebooted="$(check_rebooted "${boot_id}" "${last_lines}")"
          if [[ "${rebooted}" == "CRASH?" ]]; then
            rebooted=$(check_crashlog "${last_msg}" "${crashdir}" "${rebooted}")
          fi
        fi
      fi
      # include TZ that has more than 3 letters, skip hyphen (non-ASCI)
      local first_msg="$(echo "${ary[3]} ${ary[4]} ${ary[5]}" | grep -oP '^([\w+-:0-9\s])+')"
      if [[ ${show_id} == true ]]; then
        second_col="${uuid}"
      else
        second_col="${first_msg}"
      fi

      local up="$(date_diff "${first_msg}" "${last_msg}")"
      printf "${line_format}" "${boot_id}" "${second_col}" "${last_msg}" "${up}" "${rebooted}"
    fi
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

