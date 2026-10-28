#!/bin/bash

check_type="${1:-all}"
log_file="$(pwd)/log_agsbx.log"
: >"$log_file"

log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') $*" | tee -a "$log_file"
}

run_argosbx() {
  local sub="$1"
  log "执行 argosbx.sh $sub ..."

  bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosbx/main/argosbx.sh) "$sub" >>"$log_file" 2>&1
  local rc=$?
  log "argosbx.sh $sub 执行完毕, 退出码: $rc"

  return $rc
}

# 先卸载(del)再部署（检测失败时的统一恢复动作）
deploy() {
  local script="$(pwd)/deploy_agsbx.sh"
  log "$1"

  if [[ -f "$script" ]]; then
    run_argosbx del

    bash "$script" >>"$log_file" 2>&1
    local rc=$?
    log "deploy_agsbx.sh 执行完毕, 退出码: $rc"
    return $rc
  fi

  log "deploy_agsbx.sh 不存在, 回退执行 run_res..."
  run_res "回退重启"
}

run_res() {
  log "$1"

  output=$(bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosbx/main/argosbx.sh) res 2>&1)
  echo "$output" >>"$log_file"

  if echo "$output" | grep -q "未安装"; then
    log "检测到未安装状态，执行部署脚本..."
    deploy "开始部署..."
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
  log "tunnel 未运行"
  deploy "开始执行 deploy_agsbx.sh..."
  exit $?
  ;;
x)
  [[ $xray_exists -eq 0 ]] && log "xray 正在运行, 退出..." && exit 0
  log "xray 未运行"
  deploy "开始执行 deploy_agsbx.sh..."
  exit $?
  ;;
s)
  [[ $sbox_exists -eq 0 ]] && log "singbox 正在运行, 退出..." && exit 0
  log "singbox 未运行"
  deploy "开始执行 deploy_agsbx.sh..."
  exit $?
  ;;
xt)
  [[ $xray_exists -eq 0 && $tunnel_exists -eq 0 ]] && log "xray 和 tunnel 正在运行, 退出..." && exit 0
  log "xray 或 tunnel 未运行"
  deploy "开始执行 deploy_agsbx.sh..."
  exit $?
  ;;
st)
  [[ $sbox_exists -eq 0 && $tunnel_exists -eq 0 ]] && log "singbox 和 tunnel 正在运行, 退出..." && exit 0
  log "singbox 或 tunnel 未运行"
  deploy "开始执行 deploy_agsbx.sh..."
  exit $?
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
