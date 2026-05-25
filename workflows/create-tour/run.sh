#!/usr/bin/env bash
# create-tour · 立项一个新团组：建内部群 + 建文档目录 + 在 Base 新建主表行
# 依赖：lark-cli (auth login 完成)、jq
# 用法见 README.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.sh"

# ===== 参数解析 =====
DRY_RUN=0
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --help|-h)
            sed -n '/^# 用法/,/^$/p' "${SCRIPT_DIR}/README.md" 2>/dev/null || cat "${SCRIPT_DIR}/README.md"
            exit 0 ;;
        *) ARGS+=("$1"); shift ;;
    esac
done

if [[ ${#ARGS[@]} -lt 5 ]]; then
    echo "❌ 参数不足。用法： $0 <团号> <类型> <目的地> <出发日期 YYYY-MM-DD> <天数> [主题]" >&2
    echo "   示例： $0 YX-2607-HZ-01 学生研学 杭州 2026-07-10 6 \"宋韵研学\"" >&2
    exit 2
fi

TOUR_ID="${ARGS[0]}"
TOUR_TYPE="${ARGS[1]}"
DEST="${ARGS[2]}"
DEPART="${ARGS[3]}"
DAYS="${ARGS[4]}"
THEME="${ARGS[5]:-}"

# ===== 团号规则校验 YX-YYMM-XX-NN =====
if ! [[ "${TOUR_ID}" =~ ^YX-[0-9]{4}-[A-Z]{2,3}-[0-9]{2}$ ]]; then
    echo "❌ 团号格式错误：${TOUR_ID}" >&2
    echo "   期望：YX-YYMM-XX-NN，如 YX-2607-HZ-01" >&2
    exit 2
fi

# 计算返回日期
RETURN_DATE=$(date -j -v+"$((DAYS-1))"d -f "%Y-%m-%d" "${DEPART}" "+%Y-%m-%d" 2>/dev/null || \
              date -d "${DEPART} +$((DAYS-1)) days" "+%Y-%m-%d")

echo "=========================================="
echo "  团组立项：${TOUR_ID}"
echo "  类型：${TOUR_TYPE} | 目的地：${DEST}"
echo "  日期：${DEPART} → ${RETURN_DATE} (${DAYS} 天)"
echo "  主题：${THEME:-(未填)}"
[[ "${DRY_RUN}" == "1" ]] && echo "  ⚠️ DRY RUN 模式：只打印动作，不真正执行"
echo "=========================================="

# ===== 检查团号是否已存在 =====
echo
echo "[1/4] 检查团号唯一性..."
EXISTING=$(lark-cli base +record-search \
    --base-token "${BASE_TOKEN}" \
    --table-id "${MAIN_TABLE_ID}" \
    --json "{\"filter\":{\"conjunction\":\"and\",\"conditions\":[{\"field_name\":\"团号\",\"operator\":\"is\",\"value\":[\"${TOUR_ID}\"]}]}}" \
    --as user 2>/dev/null | jq -r '.data.items[0].record_id // empty' 2>/dev/null || echo "")

if [[ -n "${EXISTING}" ]]; then
    echo "❌ 团号已存在：${TOUR_ID} (record_id=${EXISTING})" >&2
    exit 3
fi
echo "✅ 团号可用"

# ===== Step 2: 建内部团控群 =====
echo
echo "[2/4] 建内部团控群「[团控] ${TOUR_ID} ${DEST}」..."
CHAT_NAME="[团控] ${TOUR_ID} ${DEST}"
if [[ "${DRY_RUN}" == "1" ]]; then
    echo "  [dry-run] 会创建群：${CHAT_NAME}"
    CHAT_ID="oc_dryrun_$(date +%s)"
else
    CHAT_RESULT=$(lark-cli im +chat-create \
        --name "${CHAT_NAME}" \
        --description "团号 ${TOUR_ID} · ${DEST} · 出团日 ${DEPART} · 内部团控用" \
        --as user 2>&1) || { echo "❌ 建群失败：${CHAT_RESULT}" >&2; exit 4; }
    CHAT_ID=$(echo "${CHAT_RESULT}" | jq -r '.data.chat_id // .data.chat.chat_id // empty')
    [[ -z "${CHAT_ID}" ]] && { echo "❌ 取不到 chat_id：${CHAT_RESULT}" >&2; exit 4; }
    echo "✅ 群已建：${CHAT_ID}"
fi

# ===== Step 3: 建文档目录 =====
echo
echo "[3/4] 在「研学团组管理」下建团组子目录..."
FOLDER_NAME="${TOUR_ID} ${DEST}"
if [[ "${DRY_RUN}" == "1" ]]; then
    echo "  [dry-run] 会建文件夹：${FOLDER_NAME}，并预置 01/02/03/04 子项"
    SUBFOLDER_TOKEN="fld_dryrun"
else
    FOLDER_RESULT=$(lark-cli drive +create-folder \
        --name "${FOLDER_NAME}" \
        --folder-token "${ROOT_FOLDER_TOKEN}" \
        --as user 2>&1) || { echo "❌ 建目录失败：${FOLDER_RESULT}" >&2; exit 5; }
    SUBFOLDER_TOKEN=$(echo "${FOLDER_RESULT}" | jq -r '.data.folder_token // empty')
    [[ -z "${SUBFOLDER_TOKEN}" ]] && { echo "❌ 取不到 folder_token" >&2; exit 5; }
    echo "✅ 目录已建：${SUBFOLDER_TOKEN}"

    # 预置 4 项（用空 docx 文件创建，飞书 docx create 走 docx 域，先简化只建文件夹层级）
    # 备注：预置文档暂时省略 docx 自动建（docx 创建 API 较繁琐），先建子文件夹方便手工新建
    for sub in "01-行程方案" "02-研学手册" "03-合作协议" "04-5单1书"; do
        lark-cli drive +create-folder \
            --name "$sub" \
            --folder-token "${SUBFOLDER_TOKEN}" \
            --as user >/dev/null 2>&1 && echo "    ✓ 建子目录 $sub" || echo "    ⚠ 跳过 $sub"
    done
fi
DOC_FOLDER_URL="https://ccn3ixoh82kp.feishu.cn/drive/folder/${SUBFOLDER_TOKEN}"

# ===== Step 4: 在 Base 新建主表行 =====
echo
echo "[4/4] Base 写入主表「团组」记录..."
RECORD_JSON=$(cat <<JSONEOF
{
  "团号": "${TOUR_ID}",
  "团组类型": "${TOUR_TYPE}",
  "出发日期": "${DEPART} 00:00:00",
  "返回日期": "${RETURN_DATE} 00:00:00",
  "天数": ${DAYS},
  "目的地": "${DEST}",
  "主题/目标": "${THEME}",
  "状态": "已立项",
  "出团日": "${DEPART} 00:00:00"
}
JSONEOF
)

if [[ "${DRY_RUN}" == "1" ]]; then
    echo "  [dry-run] 会写入 Base 主表："
    echo "${RECORD_JSON}" | sed 's/^/    /'
    REC_ID="rec_dryrun"
else
    REC_RESULT=$(lark-cli base +record-upsert \
        --base-token "${BASE_TOKEN}" \
        --table-id "${MAIN_TABLE_ID}" \
        --json "${RECORD_JSON}" \
        --as user 2>&1) || { echo "❌ Base 写入失败：${REC_RESULT}" >&2; exit 6; }
    # 仅取最后一个 JSON 对象（CLI 可能先输出 stderr 提示）
    REC_ID=$(echo "${REC_RESULT}" | python3 -c "
import json,sys,re
raw=sys.stdin.read()
m=re.search(r'\{.*\}',raw,re.S)
if m:
    try:
        d=json.loads(m.group(0))
        print(d.get('data',{}).get('record',{}).get('id') or d.get('data',{}).get('record_id') or '')
    except: pass
" 2>/dev/null)
    [[ -z "${REC_ID}" ]] && REC_ID="(已写入，未取到 ID)"
    echo "✅ Base 记录已建：${REC_ID}"
fi

# ===== 输出汇总 =====
echo
echo "=========================================="
echo "🎉 团组 ${TOUR_ID} 立项完成"
echo "=========================================="
echo "  内部群     : ${CHAT_NAME}"
echo "  群 ID      : ${CHAT_ID}"
echo "  文档目录   : ${DOC_FOLDER_URL}"
echo "  Base 记录  : ${REC_ID}"
echo "  Base 链接  : https://ccn3ixoh82kp.feishu.cn/base/${BASE_TOKEN}?table=${MAIN_TABLE_ID}"
echo
echo "💡 下一步建议："
echo "  - 把团控、课程部、财务拉进内部群"
echo "  - 在 Base 里补全字段：报价/成本/客方/人力 等"
echo "  - 在文档目录 01/02/03/04 子目录里新建对应飞书文档"
echo "=========================================="
