#!/bin/bash
# cw - Claude Code 멀티 워크플로우 관리
# tmux + git worktree로 병렬 작업 환경 구성
#
# 버전: 1.3.0
# 설치: curl -o ~/bin/cw <URL> && chmod +x ~/bin/cw
#
# 안전 정책:
#   - 메인 프로젝트 디렉토리는 절대 삭제 안 함
#   - 커밋 안 된 변경사항 있으면 삭제 차단
#   - 삭제 전 항상 확인 질문

set -e

VERSION="1.3.0"

# 설정 (현재 디렉토리 기반)
PROJECT_ROOT="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
WORKTREE_BASE="$(dirname "$PROJECT_ROOT")"
SESSION_NAME="cw-${PROJECT_NAME}"

# 메인 worktree 경로 (보호용 - git 기반으로 정확히 감지)
get_main_worktree() {
    git worktree list --porcelain 2>/dev/null | grep "^worktree " | head -1 | sed 's/^worktree //'
}

# 색상 (NO_COLOR 환경변수 지원)
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' NC=''
fi

log_info() { echo -e "${BLUE}▶${NC} $1"; }
log_ok() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

check_git() {
    git rev-parse --git-dir > /dev/null 2>&1 || {
        log_error "Git 저장소가 아닙니다"
        exit 1
    }
}

# 변경사항 개수 확인 (서브쉘로 디렉토리 영향 없음)
get_changes() {
    local path="$1"
    if [ -d "$path" ]; then
        (cd "$path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    else
        echo "0"
    fi
}

# 브랜치 존재 확인 (로컬 + 원격)
branch_exists() {
    local branch="$1"
    # 로컬 브랜치 확인
    git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null && return 0
    # 원격 브랜치 확인
    git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null && return 0
    return 1
}

# 원격 브랜치를 로컬로 가져오기
fetch_remote_branch() {
    local branch="$1"
    if git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
        log_info "원격 브랜치 가져오는 중: origin/$branch"
        git fetch origin "$branch:$branch" 2>/dev/null || true
        return 0
    fi
    return 1
}

# ============================================================
show_help() {
    cat << 'EOF'

  ╭─────────────────────────────────────────────────────────╮
  │  cw - Claude Code 멀티 워크플로우                       │
  ╰─────────────────────────────────────────────────────────╯

  사용법: cd <프로젝트> && cw <명령어>

  명령어:
    start                           tmux 세션 시작 (main/git/dev 윈도우)
    add <name> [branch] [start]     워크플로우 추가 (새 worktree + claude)
    rm <name>                       워크플로우 제거 (안전 검사)
    rm <name> --force               강제 제거
    ls                              목록 보기
    attach                          세션 연결
    stop                            세션 종료 (worktree 유지)
    clean                           빈 worktree 정리
    status                          상태 확인

  브랜치 동작:
    • 기존 브랜치 (로컬/원격) → 그대로 사용
    • 새 브랜치 생성 → start-point 기준 (기본값: origin/master)
    • origin/* 시작점 → 자동으로 fetch 후 사용

  예시:
    cw start                        # 세션 시작
    cw add ticket feat/ticket       # 기존 feat/ticket 브랜치 사용
    cw add api                      # origin/master 기준 feat/api 새 브랜치
    cw add fix feat/fix origin/dev  # origin/dev 기준 feat/fix 새 브랜치
    cw ls                           # 목록
    cw rm ticket                    # 제거
    cw stop                         # 세션만 종료

  안전 정책:
    • 메인 프로젝트 폴더는 절대 삭제 안 함
    • 커밋 안 된 변경사항 있으면 삭제 차단
    • --force로만 강제 삭제 가능

  tmux 단축키:
    Ctrl+B, 0-9    윈도우 전환
    Ctrl+B, w      윈도우 목록
    Ctrl+B, d      세션 분리 (백그라운드)

  팀 설치 가이드:
    1. 스크립트 다운로드
       mkdir -p ~/bin
       cp /path/to/cw ~/bin/cw
       chmod +x ~/bin/cw

    2. PATH 추가 (~/.zshrc 또는 ~/.bashrc)
       export PATH="$HOME/bin:$PATH"

    3. 적용
       source ~/.zshrc

EOF
}

# ============================================================
cmd_start() {
    check_git
    command -v tmux &>/dev/null || { log_error "tmux 필요: brew install tmux"; exit 1; }

    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        log_warn "세션이 이미 있습니다. 연결합니다..."
        tmux attach-session -t "$SESSION_NAME"
        exit 0
    fi

    log_info "세션 생성: ${BOLD}$SESSION_NAME${NC}"

    tmux new-session -d -s "$SESSION_NAME" -n "main" -c "$PROJECT_ROOT"
    tmux send-keys -t "$SESSION_NAME:main" "claude" Enter

    tmux new-window -t "$SESSION_NAME" -n "git" -c "$PROJECT_ROOT"
    tmux send-keys -t "$SESSION_NAME:git" "git status && echo '' && git worktree list" Enter

    tmux new-window -t "$SESSION_NAME" -n "dev" -c "$PROJECT_ROOT"

    tmux select-window -t "$SESSION_NAME:main"

    echo ""
    log_ok "세션 생성 완료"
    echo ""
    echo "  [0] main - Claude Code (메인 브랜치)"
    echo "  [1] git  - Git 명령어 & cw add/rm"
    echo "  [2] dev  - 개발/테스트"
    echo ""

    tmux attach-session -t "$SESSION_NAME"
}

# ============================================================
cmd_add() {
    check_git
    local name="$1"
    local branch="${2:-feat/${name}}"
    local start_point="${3:-origin/master}"

    [ -z "$name" ] && { log_error "이름 필요: cw add <name> [branch] [start-point]"; exit 1; }
    tmux has-session -t "$SESSION_NAME" 2>/dev/null || { log_error "세션 없음. 먼저 'cw start'"; exit 1; }

    local wt_path="${WORKTREE_BASE}/${PROJECT_NAME}-${name}"

    # Worktree 생성
    if [ ! -d "$wt_path" ]; then
        log_info "Worktree 생성: ${BOLD}$wt_path${NC}"

        # 로컬 브랜치 확인
        if git show-ref --verify --quiet "refs/heads/$branch"; then
            log_info "로컬 브랜치 사용: $branch"
            git worktree add "$wt_path" "$branch"
        # 원격 브랜치 확인 및 가져오기
        elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
            log_info "원격 브랜치 가져오기: origin/$branch"
            git fetch origin "$branch"
            git worktree add "$wt_path" "$branch"
        # 새 브랜치 생성 (start-point 기준)
        else
            # origin/* 형태면 fetch 먼저 실행
            if [[ "$start_point" == origin/* ]]; then
                local remote_branch="${start_point#origin/}"
                log_info "$start_point 최신화 중..."
                git fetch origin "$remote_branch"
            fi
            log_info "새 브랜치 생성: $branch (from $start_point)"
            git worktree add "$wt_path" -b "$branch" "$start_point"
        fi

        # 의존성 설치
        log_info "의존성 설치 중..."
        (
            cd "$wt_path"
            if [ -f "pnpm-lock.yaml" ]; then
                pnpm install 2>/dev/null || pnpm install --no-frozen-lockfile
            elif [ -f "yarn.lock" ]; then
                yarn install --frozen-lockfile 2>/dev/null || yarn install
            elif [ -f "package-lock.json" ]; then
                npm ci 2>/dev/null || npm install
            fi
        )
    else
        log_warn "Worktree 이미 존재: $wt_path"
    fi

    # tmux 윈도우 (grep -F로 리터럴 매칭)
    if ! tmux list-windows -t "$SESSION_NAME" -F "#W" | grep -Fx "$name" > /dev/null; then
        tmux new-window -t "$SESSION_NAME" -n "$name" -c "$wt_path"
        tmux send-keys -t "$SESSION_NAME:$name" "claude" Enter
    else
        log_warn "윈도우 이미 존재: $name"
    fi

    echo ""
    log_ok "${BOLD}$name${NC} 추가 완료"
    echo "  경로: $wt_path"
    echo "  브랜치: $branch"
    echo ""
}

# ============================================================
cmd_remove() {
    check_git
    local name="$1"
    local force="$2"

    [ -z "$name" ] && { log_error "이름 필요: cw rm <name>"; exit 1; }

    local wt_path="${WORKTREE_BASE}/${PROJECT_NAME}-${name}"

    # 메인 프로젝트 보호 (git 기반으로 정확히 감지)
    local main_wt=$(get_main_worktree)
    [ "$wt_path" = "$main_wt" ] && { log_error "메인 프로젝트는 삭제 불가!"; exit 1; }

    # 존재 확인
    if [ ! -d "$wt_path" ]; then
        log_warn "Worktree 디렉토리 없음: $wt_path"
        tmux kill-window -t "$SESSION_NAME:$name" 2>/dev/null || true
        git worktree prune
        log_ok "Worktree 참조 정리 완료"
        exit 0
    fi

    # 변경사항 검사
    local changes=$(get_changes "$wt_path")

    if [ "$changes" -gt 0 ] && [ "$force" != "--force" ]; then
        echo ""
        log_error "커밋 안 된 변경사항 ${BOLD}${changes}개${NC} 있음!"
        echo ""
        echo "  경로: $wt_path"
        echo ""
        echo "  해결 방법:"
        echo "    1. 먼저 커밋: cd $wt_path && git add . && git commit"
        echo "    2. 강제 삭제: cw rm $name --force"
        echo ""
        exit 1
    fi

    # 삭제 확인
    echo ""
    echo -e "  삭제 대상: ${BOLD}$wt_path${NC}"
    [ "$changes" -gt 0 ] && echo -e "  ${RED}⚠ 변경사항 ${changes}개가 사라집니다!${NC}"
    echo ""
    read -p "  삭제하시겠습니까? (y/N): " confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { log_info "취소됨"; exit 0; }

    # 삭제 실행
    tmux kill-window -t "$SESSION_NAME:$name" 2>/dev/null || true

    cd "$PROJECT_ROOT"
    git worktree remove "$wt_path" --force 2>/dev/null || {
        rm -rf "$wt_path"
        git worktree prune
    }

    echo ""
    log_ok "${BOLD}$name${NC} 제거 완료"
    echo "  (브랜치는 git에 남아있음)"
    echo ""
}

# ============================================================
cmd_list() {
    check_git
    echo ""
    echo -e "${CYAN}━━━ $PROJECT_NAME ━━━${NC}"
    echo ""

    local main_wt=$(get_main_worktree)
    echo -e "${BOLD}Worktrees:${NC}"
    git worktree list | while read -r wt_path _ wt_branch; do
        local branch=$(echo "$wt_branch" | tr -d '[]')
        local marker=""
        local status_icon="${GREEN}●${NC}"

        [ "$wt_path" = "$main_wt" ] && marker=" ${CYAN}(메인)${NC}"

        if [ -d "$wt_path" ]; then
            local changes=$(get_changes "$wt_path")
            [ "$changes" -gt 0 ] && status_icon="${YELLOW}●${NC} ${changes}개 변경"
        fi

        echo -e "  $status_icon $branch$marker"
        echo "      $wt_path"
    done
    echo ""

    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo -e "${BOLD}tmux 윈도우:${NC}"
        tmux list-windows -t "$SESSION_NAME" -F "  [#I] #W"
    else
        echo -e "${YELLOW}tmux 세션 없음${NC}"
    fi
    echo ""
}

# ============================================================
cmd_attach() {
    tmux has-session -t "$SESSION_NAME" 2>/dev/null || { log_error "세션 없음. 'cw start' 먼저"; exit 1; }
    tmux attach-session -t "$SESSION_NAME"
}

# ============================================================
cmd_stop() {
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        tmux kill-session -t "$SESSION_NAME"
        log_ok "세션 종료 ${YELLOW}(worktree는 유지됨)${NC}"
    else
        log_info "실행 중인 세션 없음"
    fi
}

# ============================================================
cmd_clean() {
    check_git
    local main_wt=$(get_main_worktree)

    echo ""
    log_info "변경사항 없는 worktree만 정리합니다"
    echo -e "  ${GREEN}메인 프로젝트는 절대 삭제 안 함${NC}"
    echo ""

    # 먼저 목록 표시
    git worktree list | while read -r wt_path _ wt_branch; do
        [ "$wt_path" = "$main_wt" ] && continue

        local branch=$(echo "$wt_branch" | tr -d '[]')
        local changes=$(get_changes "$wt_path")

        if [ "$changes" -gt 0 ]; then
            echo -e "  ${RED}●${NC} $branch - ${changes}개 변경 (스킵)"
        else
            echo -e "  ${GREEN}●${NC} $branch - 삭제 가능"
        fi
    done

    echo ""
    read -p "  계속하시겠습니까? (y/N): " confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { log_info "취소됨"; exit 0; }

    # 실제 삭제
    git worktree list --porcelain | grep "^worktree" | while read -r line; do
        local path="${line#worktree }"
        [ "$path" = "$main_wt" ] && continue

        local changes=$(get_changes "$path")
        if [ "$changes" -eq 0 ]; then
            # worktree 이름 추출해서 tmux 윈도우도 정리
            local wt_name=$(basename "$path" | sed "s/^${PROJECT_NAME}-//")
            tmux kill-window -t "$SESSION_NAME:$wt_name" 2>/dev/null || true

            log_info "제거: $path"
            git worktree remove "$path" --force 2>/dev/null || rm -rf "$path"
        fi
    done

    git worktree prune
    log_ok "정리 완료"
}

# ============================================================
cmd_status() {
    check_git
    echo ""
    echo -e "${CYAN}━━━ $PROJECT_NAME 상태 ━━━${NC}"
    echo ""

    echo -n "tmux: "
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        local win_count=$(tmux list-windows -t "$SESSION_NAME" 2>/dev/null | wc -l | tr -d ' ')
        echo -e "${GREEN}실행 중${NC} (${win_count}개 윈도우)"
    else
        echo -e "${YELLOW}중지됨${NC}"
    fi

    echo "현재 브랜치: $(git branch --show-current)"
    echo ""

    cmd_list
}

# ============================================================
cmd_version() {
    echo "cw version $VERSION"
}

# ============================================================
case "${1:-help}" in
    start)          cmd_start ;;
    add)            shift; cmd_add "$@" ;;
    rm|remove)      shift; cmd_remove "$@" ;;
    ls|list)        cmd_list ;;
    a|attach)       cmd_attach ;;
    stop)           cmd_stop ;;
    clean)          cmd_clean ;;
    st|status)      cmd_status ;;
    -v|--version)   cmd_version ;;
    -h|--help|help|"") show_help ;;
    *) log_error "알 수 없는 명령어: $1"; show_help; exit 1 ;;
esac
