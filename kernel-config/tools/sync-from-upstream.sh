#!/bin/bash
#===========================================================================
# Woloong: 用官方 ophub/kernel 的 config-<版本> 作基线，再强制写入
#          kernel-config/required-options.conf 中声明的必需项。
#
# 用法:
#   ./sync-from-upstream.sh             # 同步 SCOPE 声明的版本（默认 6.18）
#   ./sync-from-upstream.sh 6.18        # 指定版本
#   UPSTREAM_REF=main ./sync-from-upstream.sh 6.18
#
# 策略: 官方基线 → 必需项“原地”替换（无则追加）→ 自检，diff 最小化
#===========================================================================
set -euo pipefail

kernel_config_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
req_file="${kernel_config_root}/required-options.conf"
flavor="${FLAVOR:-stable}"
upstream_repo="${UPSTREAM_REPO:-https://github.com/ophub/kernel.git}"
upstream_ref="${UPSTREAM_REF:-main}"

[[ -f "${req_file}" ]] || { echo "缺少 ${req_file}"; exit 1; }
ver="${1:-$(awk -F'=' '/^SCOPE=/{print $2; exit}' "${req_file}" | awk '{print $1}' || true)}"
[[ -n "${ver}" ]] || { echo "未指定版本，且 required-options.conf 中没有 SCOPE="; exit 1; }

target="${kernel_config_root}/release/${flavor}/config-${ver}"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

echo "[1/4] 从 ${upstream_repo} (${upstream_ref}) 拉取官方基线 ..."
git clone --quiet --depth=1 --branch "${upstream_ref}" "${upstream_repo}" "${tmp}/upstream"
src="${tmp}/upstream/kernel-config/release/${flavor}/config-${ver}"
[[ -s "${src}" ]] || { echo "官方仓库中没有 config-${ver}（flavor=${flavor}）"; exit 1; }

echo "[2/4] 以官方基线覆盖 ${target}"
cp -f "${src}" "${target}"

echo "[3/4] 原地写入必需项"
applied=0; appended=0
while IFS= read -r line; do
    [[ -z "${line}" || "${line}" == \#* || "${line}" == SCOPE=* ]] && continue
    name="${line%%=*}"
    if grep -q "^${name}=" "${target}"; then
        awk -v n="${name}" -v v="${line}" 'index($0, n "=")==1 {print v; next} {print}' "${target}" >"${target}.tmp" && mv -f "${target}.tmp" "${target}"
    elif grep -q "^# ${name} is not set$" "${target}"; then
        awk -v p="^# ${name} is not set$" -v v="${line}" '$0 ~ p {print v; next} {print}' "${target}" >"${target}.tmp" && mv -f "${target}.tmp" "${target}"
    else
        printf '\n# Woloong required\n%s\n' "${line}" >>"${target}"
        appended=$((appended + 1))
    fi
    applied=$((applied + 1))
done < "${req_file}"

echo "[4/4] 自检"
missing=0
while IFS= read -r line; do
    [[ -z "${line}" || "${line}" == \#* || "${line}" == SCOPE=* ]] && continue
    name="${line%%=*}"
    grep -q "^${name}=" "${target}" || { echo "  缺失: ${line}"; missing=$((missing + 1)); }
done < "${req_file}"
[[ "${missing}" -eq 0 ]] || { echo "自检失败：仍有 ${missing} 项缺失"; exit 1; }

echo "完成：${target}"
echo "  基线 : 官方 ${upstream_ref} 的 config-${ver}"
echo "  处理 : ${applied} 项必需项（其中 ${appended} 项为新增追加）"
echo "  下一步: git diff 复核后提交"
