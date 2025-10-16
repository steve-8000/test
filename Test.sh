#!/usr/bin/env bash
set -Eeuo pipefail

# ------------------------------------------------------------
# Ubuntu System Environment Test (disk + memory + network)
# Auto-install dependencies if missing
# ------------------------------------------------------------

is_sourced() { [[ "${BASH_SOURCE[0]}" != "$0" ]]; }
fatal() { local code=${1:-1}; shift || true; [[ $# -gt 0 ]] && echo -e "$*" 1>&2; if is_sourced; then return "$code"; else exit "$code"; fi; }

TEST_DIR="${TEST_DIR:-/opt/charon}"
TEST_FILE_SIZE_MB="${TEST_FILE_SIZE_MB:-4096}"
FIO_JOBS="${FIO_JOBS:-8}"
FIO_RUNTIME="${FIO_RUNTIME:-10}"
SPEEDTEST_SERVER_ID="${SPEEDTEST_SERVER_ID:-}"

THR_DISK_WRITE_MBPS_GOOD=${THR_DISK_WRITE_MBPS_GOOD:-800}
THR_DISK_READ_MBPS_GOOD=${THR_DISK_READ_MBPS_GOOD:-1500}
THR_WRITE_IOPS_GOOD=${THR_WRITE_IOPS_GOOD:-5000}
THR_READ_IOPS_GOOD=${THR_READ_IOPS_GOOD:-8000}
THR_NET_LATENCY_MS_GOOD=${THR_NET_LATENCY_MS_GOOD:-10}
THR_NET_DOWN_MBPS_GOOD=${THR_NET_DOWN_MBPS_GOOD:-500}
THR_NET_UP_MBPS_GOOD=${THR_NET_UP_MBPS_GOOD:-500}
THR_MEM_AVAILABLE_MB_GOOD=${THR_MEM_AVAILABLE_MB_GOOD:-4096}

C_RESET="\033[0m"; C_GREEN="\033[32m"; C_YELLOW="\033[33m"; C_RED="\033[31m"

now() { date +"%H:%M:%S.%3N"; }
log() { printf "%s INFO cmd        %s\n" "$(now)" "$*"; }

rate_status_num() { local v=$1 g=$2; (( $(awk -v v="$v" -v g="$g" 'BEGIN{print (v>=g)}') )) && echo Good || echo Poor; }
rate_status_mem() { local v=$1 g=$2; (( $(awk -v v="$v" -v g="$g" 'BEGIN{print (v>=g)}') )) && echo Good || echo Poor; }
rate_status_latency() { local v=$1 g=$2; (( $(awk -v v="$v" -v g="$g" 'BEGIN{print (v<=g)}') )) && echo Good || echo Poor; }

print_row() { printf "%-45s %12s %s\n" "$1" "$2" "$3"; }

install_deps() {
  echo -e "${C_YELLOW}Installing missing dependencies...${C_RESET}"
  sudo apt-get update -y
  sudo apt-get install -y fio jq curl
  if ! command -v speedtest >/dev/null 2>&1; then
    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
    sudo apt-get install -y speedtest
  fi
}

check_deps() {
  local missing=()
  command -v fio >/dev/null 2>&1 || missing+=("fio")
  command -v jq >/dev/null 2>&1 || missing+=("jq")
  command -v speedtest >/dev/null 2>&1 || missing+=("speedtest (Ookla CLI)")
  if ((${#missing[@]})); then
    echo -e "${C_YELLOW}Missing dependencies:${C_RESET} ${missing[*]}"
    install_deps
  fi
}

prepare_dir() {
  sudo mkdir -p "$TEST_DIR" >/dev/null 2>&1 || mkdir -p "$TEST_DIR"
}

disk_write_speed() {
  fio --name=seqwrite --filename="$TEST_DIR/fio_testfile" --size=${TEST_FILE_SIZE_MB}m --bs=1m --rw=write --iodepth=64 --numjobs=${FIO_JOBS} --direct=1 --ioengine=libaio --group_reporting=1 --output-format=json 2>/dev/null | jq -r '[.jobs[].write.bw_bytes] | add / 1048576 | @json'
}

disk_write_iops() {
  fio --name=randwrite --filename="$TEST_DIR/fio_testfile" --size=${TEST_FILE_SIZE_MB}m --bs=4k --rw=randwrite --iodepth=64 --numjobs=${FIO_JOBS} --direct=1 --ioengine=libaio --time_based=1 --runtime=${FIO_RUNTIME} --group_reporting=1 --output-format=json 2>/dev/null | jq -r '[.jobs[].write.iops] | add | @json'
}

disk_read_speed() {
  fio --name=seqread --filename="$TEST_DIR/fio_testfile" --size=${TEST_FILE_SIZE_MB}m --bs=1m --rw=read --iodepth=64 --numjobs=${FIO_JOBS} --direct=1 --ioengine=libaio --group_reporting=1 --output-format=json 2>/dev/null | jq -r '[.jobs[].read.bw_bytes] | add / 1048576 | @json'
}

disk_read_iops() {
  fio --name=randread --filename="$TEST_DIR/fio_testfile" --size=${TEST_FILE_SIZE_MB}m --bs=4k --rw=randread --iodepth=64 --numjobs=${FIO_JOBS} --direct=1 --ioengine=libaio --time_based=1 --runtime=${FIO_RUNTIME} --group_reporting=1 --output-format=json 2>/dev/null | jq -r '[.jobs[].read.iops] | add | @json'
}

mem_info() { awk '/MemTotal:/{t=$2} /MemAvailable:/{a=$2} END{printf("%d,%d\n", a/1024, t/1024)}' /proc/meminfo; }

net_speedtest() {
  if ! command -v speedtest >/dev/null 2>&1; then return 1; fi
  if [[ -n "$SPEEDTEST_SERVER_ID" ]]; then
    speedtest --accept-license --accept-gdpr --server-id="$SPEEDTEST_SERVER_ID" --format=json
  else
    speedtest --accept-license --accept-gdpr --format=json
  fi
}

main() {
  local start_ts=$(date +%s%N)
  check_deps || true
  prepare_dir

  log "Starting hardware performance and network connectivity test"

  log "Testing disk write speed...              {\"test_file_size_mb\": \"$TEST_FILE_SIZE_MB\", \"jobs\": \"$FIO_JOBS\", \"test_file_path\": \"$TEST_DIR\"}"
  local w_mb=$(disk_write_speed)

  log "Testing disk write IOPS...               {\"test_file_size_mb\": \"$TEST_FILE_SIZE_MB\", \"jobs\": \"$FIO_JOBS\", \"test_file_path\": \"$TEST_DIR\"}"
  local w_iops=$(disk_write_iops)

  log "Testing disk read speed...               {\"test_file_size_mb\": \"$TEST_FILE_SIZE_MB\", \"jobs\": \"$FIO_JOBS\", \"test_file_path\": \"$TEST_DIR\"}"
  local r_mb=$(disk_read_speed)

  log "Testing disk read IOPS...                {\"test_file_size_mb\": \"$TEST_FILE_SIZE_MB\", \"jobs\": \"$FIO_JOBS\", \"test_file_path\": \"$TEST_DIR\"}"
  local r_iops=$(disk_read_iops)

  log "Testing internet latency...              {\"server\": \"auto or provided\"}"
  local net_json
  if ! net_json=$(net_speedtest); then
    echo -e "${C_YELLOW}Network speedtest skipped or failed. Proceeding without network metrics.${C_RESET}" >&2
    net_json='{}'
  fi

  local server_name server_loc server_id server_dist_km latency_ms down_bps up_bps
  server_name=$(jq -r '.server.name // "N/A"' <<<"$net_json")
  server_loc=$(jq -r '.server.location // "N/A"' <<<"$net_json")
  server_id=$(jq -r '.server.id // "N/A"' <<<"$net_json")
  server_dist_km=$(jq -r '.server.distance.kilometers // .server.distance // "N/A"' <<<"$net_json")
  latency_ms=$(jq -r '.ping.latency // "NaN"' <<<"$net_json")
  down_bps=$(jq -r '.download.bandwidth // 0' <<<"$net_json")
  up_bps=$(jq -r '.upload.bandwidth // 0' <<<"$net_json")

  log "Testing internet download speed...       {\"server_name\": \"$server_name\", \"server_country\": \"$server_loc\", \"server_distance_km\": \"$server_dist_km\", \"server_id\": \"$server_id\"}"
  log "Testing internet upload speed...         {\"server_name\": \"$server_name\", \"server_country\": \"$server_loc\", \"server_distance_km\": \"$server_dist_km\", \"server_id\": \"$server_id\"}"

  local down_MBps up_MBps
  down_MBps=$(awk -v bps="$down_bps" 'BEGIN{printf("%.2f", bps/1048576)}')
  up_MBps=$(awk -v bps="$up_bps" 'BEGIN{printf("%.2f", bps/1048576)}')

  local mem_csv avail_mb total_mb
  mem_csv=$(mem_info)
  avail_mb=${mem_csv%%,*}; total_mb=${mem_csv##*,}

  printf "TEST NAME                                                       RESULT\n\n"
  echo "local"
  print_row "DiskWriteSpeed" "$(printf "%.2fMB/s" "$w_mb")" "$(rate_status_num "$w_mb" "$THR_DISK_WRITE_MBPS_GOOD")"
  print_row "DiskWriteIOPS" "$(printf "%d" "${w_iops%.*}")" "$(rate_status_num "$w_iops" "$THR_WRITE_IOPS_GOOD")"
  print_row "DiskReadSpeed" "$(printf "%.2fMB/s" "$r_mb")" "$(rate_status_num "$r_mb" "$THR_DISK_READ_MBPS_GOOD")"
  print_row "DiskReadIOPS" "$(printf "%d" "${r_iops%.*}")" "$(rate_status_num "$r_iops" "$THR_READ_IOPS_GOOD")"
  print_row "AvailableMemory" "${avail_mb}MB" "$(rate_status_mem "$avail_mb" "$THR_MEM_AVAILABLE_MB_GOOD")"
  print_row "TotalMemory" "${total_mb}MB" "Good"
  print_row "InternetLatency" "${latency_ms%.*}ms" "$( [[ "$latency_ms" == "NaN" ]] && echo "Poor" || rate_status_latency "${latency_ms%.*}" "$THR_NET_LATENCY_MS_GOOD" )"
  print_row "InternetDownloadSpeed" "${down_MBps}MB/s" "$(rate_status_num "$down_MBps" "$THR_NET_DOWN_MBPS_GOOD")"
  print_row "InternetUploadSpeed" "${up_MBps}MB/s" "$(rate_status_num "$up_MBps" "$THR_NET_UP_MBPS_GOOD")"
  echo

  local end_ts=$(date +%s%N)
  local dur_ns=$((end_ts - start_ts))
  awk -v ns="$dur_ns" 'BEGIN{printf("%.9fs\n", ns/1e9)}'

  rm -f "$TEST_DIR/fio_testfile" 2>/dev/null || true
}

main "$@"
