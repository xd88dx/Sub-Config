#!/bin/bash

check_type="${1:-all}"
log_file="$(pwd)/log_agsbx.log"
: >"$log_file"

log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') $*" | tee -a "$log_file"
}

run_res() {
  log "$1"

  output=$(bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosbx/main/argosbx.sh) res 2>&1)
  echo "$output" >>"$log_file"

  if echo "$output" | grep -q "未安装"; then
    log "检测到未安装状态，执行部署脚本..."
    "$(pwd)/deploy_agsbx.sh" >>"$log_file" 2>&1
  fi
}

log "执行身份：$(whoami)"

# 校验参数
if [[ ! "$check_type" =~ ^(keep|xt|st|t|x|s|all)$ ]]; then
  log "无效参数: $check_type，只支持 keep、st、xt、t、x、s"
  exit 1
fi

# 每日重启
[[ "$check_type" == "keep" ]] && run_res "每日重启" && exit 0

# 进程检测
pgrep -f "[a]gsbx/xray" >/dev/null 2>&1 && xray_exists=0 || xray_exists=1
pgrep -f '[a]gsbx/sing' >/dev/null 2>&1 && sbox_exists=0 || sbox_exists=1
pgrep -f "[a]gsbx/cloud" >/dev/null 2>&1 && tunnel_exists=0 || tunnel_exists=1

case "$check_type" in
t)
  [[ $tunnel_exists -eq 0 ]] && log "tunnel 正在运行, 退出..." && exit 0
  log "tunnel 未运行" && exit 1
  ;;
x)
  [[ $xray_exists -eq 0 ]] && log "xray 正在运行, 退出..." && exit 0
  log "xray 未运行" && exit 1
  ;;
s)
  [[ $sbox_exists -eq 0 ]] && log "singbox 正在运行, 退出..." && exit 0
  log "singbox 未运行" && exit 1
  ;;
xt)
  [[ $xray_exists -eq 0 && $tunnel_exists -eq 0 ]] && log "xray 和 tunnel 正在运行, 退出..." && exit 0
  log "xray 或 tunnel 未运行" && exit 1
  ;;
st)
  [[ $sbox_exists -eq 0 && $tunnel_exists -eq 0 ]] && log "singbox 和 tunnel 正在运行, 退出..." && exit 0
  log "singbox 或 tunnel 未运行" && exit 1
  ;;
*)
  if [[ $tunnel_exists -eq 1 ]]; then
    log "tunnel 未运行，准备重启服务器..."
    reboot
  elif [[ ! ($xray_exists -eq 0 && $sbox_exists -eq 0 && $tunnel_exists -eq 0) ]]; then
    run_res "进程检测失败, 开始重启..."
  else
    log "agsbx 正在运行, 退出..." && exit 0
  fi
  ;;
esac
