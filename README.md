# cw - Claude Code 멀티 워크플로우 CLI

tmux와 git worktree를 조합하여 여러 브랜치에서 Claude Code를 동시에 실행할 수 있는 병렬 작업 환경을 제공합니다.

## 📋 목차

- [소개](#소개)
- [주요 기능](#주요-기능)
- [설치 방법](#설치-방법)
- [사용 방법](#사용-방법)
- [명령어 가이드](#명령어-가이드)
- [실전 예시](#실전-예시)
- [안전 정책](#안전-정책)
- [문제 해결](#문제-해결)
- [제거 방법](#제거-방법)

## 소개

`cw`(Claude Workflow)는 Git worktree와 tmux를 활용하여 여러 브랜치에서 Claude Code를 병렬로 실행할 수 있게 해주는 CLI 도구입니다.

### 왜 cw를 사용하나요?

일반적인 개발 상황:
- ✅ 기능 A 작업 중
- ⚠️ 긴급 버그 발견!
- 😰 브랜치를 전환하면 작업 중인 내용 손실
- 😰 stash를 사용하면 복잡하고 번거로움

`cw` 사용 시:
- ✅ 기능 A 작업 중 (main 윈도우)
- ✅ `cw add bugfix` - 새 worktree에서 버그 수정 (bugfix 윈도우)
- ✅ `Ctrl+B, 0` - 기능 A로 즉시 복귀
- ✅ 두 작업을 tmux 윈도우로 빠르게 전환하며 작업!

### 핵심 개념

1. **Git Worktree**: 하나의 저장소에서 여러 브랜치를 동시에 체크아웃
2. **tmux 세션**: 각 worktree마다 독립적인 터미널 윈도우
3. **Claude Code 자동 실행**: 각 윈도우에서 claude가 자동으로 실행

## 주요 기능

| 명령어 | 기능 | 설명 |
|--------|------|------|
| `cw start` | 세션 시작 | tmux 세션과 기본 윈도우 생성 |
| `cw add <name> [branch] [start]` | 워크플로우 추가 | 새 worktree 생성 + Claude 실행 |
| `cw rm <name>` | 워크플로우 제거 | worktree와 tmux 윈도우 삭제 |
| `cw ls` | 목록 보기 | 모든 worktree와 윈도우 목록 |
| `cw attach` | 세션 연결 | 백그라운드 세션에 다시 연결 |
| `cw stop` | 세션 종료 | tmux 세션 종료 (worktree 유지) |
| `cw clean` | 정리 | 변경사항 없는 worktree 자동 정리 |
| `cw status` | 상태 확인 | 현재 상태와 통계 확인 |

## 설치 방법

### 요구사항

- **Git** 2.5 이상 (worktree 지원)
- **tmux** (터미널 멀티플렉서)
- **Claude Code** CLI

설치 확인:
```bash
git --version    # 2.5.0 이상
tmux -V          # tmux 필요
claude --version # Claude Code CLI
```

### tmux 설치

```bash
# macOS
brew install tmux

# Ubuntu/Debian
sudo apt install tmux

# Fedora
sudo dnf install tmux
```

### cw 설치

#### 방법 1: 스크립트 다운로드 (권장)

```bash
# 1. 디렉토리 생성
mkdir -p ~/bin

# 2. 스크립트 다운로드
curl -o ~/bin/cw https://raw.githubusercontent.com/lu1ee/cw/main/cw
chmod +x ~/bin/cw

# 3. PATH 추가 (아직 없다면)
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

#### 방법 2: 저장소 클론

```bash
# 1. 저장소 클론
git clone https://github.com/lu1ee/cw.git ~/bin/cw-cli

# 2. 심볼릭 링크 생성
ln -s ~/bin/cw-cli/cw ~/bin/cw

# 3. PATH 추가 (아직 없다면)
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### 설치 확인

```bash
cw --version
# 출력: cw version 1.3.0

cw --help
# 도움말 표시
```

## 사용 방법

### 기본 워크플로우

```bash
# 1. 프로젝트 디렉토리로 이동
cd ~/projects/myapp

# 2. 세션 시작
cw start

# 3. 새 워크플로우 추가
cw add feature feat/new-feature

# 4. 윈도우 전환: Ctrl+B, 숫자키
#    [0] main - 메인 브랜치
#    [1] git - Git 명령어
#    [2] dev - 개발/테스트
#    [3] feature - 새 기능 개발

# 5. 작업 완료 후 제거
cw rm feature

# 6. 세션 종료
cw stop
```

## 명령어 가이드

### `cw start` - 세션 시작

tmux 세션을 시작하고 기본 윈도우 3개를 생성합니다.

```bash
cd ~/projects/myapp
cw start
```

**생성되는 윈도우:**
- `[0] main` - Claude Code 실행 (메인 브랜치)
- `[1] git` - Git 상태 확인 및 cw 명령어 실행
- `[2] dev` - 개발/테스트용 빈 터미널

**이미 세션이 있으면:**
- 자동으로 기존 세션에 연결됩니다.

### `cw add` - 워크플로우 추가

새로운 worktree를 생성하고 tmux 윈도우를 추가합니다.

```bash
cw add <name> [branch] [start-point]
```

**매개변수:**
- `<name>` (필수): worktree 이름 (tmux 윈도우 이름으로도 사용)
- `[branch]` (선택): 브랜치 이름 (기본값: `feat/<name>`)
- `[start-point]` (선택): 시작점 (기본값: `origin/master`)

**브랜치 동작:**

1. **기존 로컬 브랜치가 있으면** → 그대로 사용
   ```bash
   cw add ticket feat/ticket
   # feat/ticket 브랜치가 이미 있으면 그대로 사용
   ```

2. **원격 브랜치가 있으면** → fetch 후 사용
   ```bash
   cw add ticket feat/ticket
   # origin/feat/ticket이 있으면 가져와서 사용
   ```

3. **브랜치가 없으면** → 새로 생성
   ```bash
   cw add api
   # origin/master 기준으로 feat/api 브랜치 생성

   cw add fix feat/fix origin/dev
   # origin/dev 기준으로 feat/fix 브랜치 생성
   ```

**예시:**

```bash
# 1. 기본 사용 (feat/api 브랜치 자동 생성)
cw add api

# 2. 브랜치 이름 지정
cw add ticket feat/ticket

# 3. 특정 브랜치를 시작점으로 사용
cw add hotfix feat/hotfix origin/release

# 4. 커밋 해시를 시작점으로 사용
cw add rollback feat/rollback abc123
```

**자동 처리:**
- 📦 의존성 자동 설치 (pnpm/yarn/npm 자동 감지)
- 🚀 Claude Code 자동 실행
- 🔗 tmux 윈도우 자동 생성

**생성 위치:**
- 프로젝트: `/Users/user/projects/myapp`
- worktree: `/Users/user/projects/myapp-api`

### `cw rm` - 워크플로우 제거

worktree와 tmux 윈도우를 삭제합니다.

```bash
# 안전한 제거 (커밋 안 된 변경사항 있으면 차단)
cw rm <name>

# 강제 제거 (변경사항 무시)
cw rm <name> --force
```

**안전 검사:**
1. 메인 프로젝트 디렉토리는 절대 삭제 불가
2. 커밋 안 된 변경사항이 있으면 삭제 차단
3. 삭제 전 확인 질문

**예시:**

```bash
# 1. 안전한 제거
cw rm api
# → 커밋 안 된 변경사항이 있으면 에러

# 2. 강제 제거
cw rm api --force
# → 변경사항 무시하고 삭제 (주의!)
```

**주의사항:**
- worktree만 삭제되며, Git 브랜치는 남아있습니다
- 브랜치를 삭제하려면: `git branch -d <branch>`

### `cw ls` - 목록 보기

모든 worktree와 tmux 윈도우 목록을 표시합니다.

```bash
cw ls
```

**출력 예시:**
```
━━━ myapp ━━━

Worktrees:
  ● main (메인)
      /Users/user/projects/myapp
  ● 3개 변경 feat/api
      /Users/user/projects/myapp-api
  ● feat/ticket
      /Users/user/projects/myapp-ticket

tmux 윈도우:
  [0] main
  [1] git
  [2] dev
  [3] api
  [4] ticket
```

**상태 표시:**
- `●` 녹색: 변경사항 없음
- `●` 노란색: 커밋 안 된 변경사항 있음 (개수 표시)

### `cw attach` - 세션 연결

백그라운드에 있는 tmux 세션에 다시 연결합니다.

```bash
cw attach
```

**사용 시나리오:**
- tmux 세션에서 `Ctrl+B, d`로 분리(detach)한 경우
- 터미널을 닫았지만 세션은 살아있는 경우

### `cw stop` - 세션 종료

tmux 세션을 종료합니다. **worktree는 삭제되지 않습니다.**

```bash
cw stop
```

**주의:**
- tmux 세션만 종료됨
- worktree와 파일들은 그대로 유지됨
- 다시 작업하려면: `cw start` → `cw attach`

### `cw clean` - 자동 정리

변경사항이 없는 worktree를 자동으로 정리합니다.

```bash
cw clean
```

**동작:**
1. 모든 worktree 스캔
2. 변경사항 없는 worktree만 표시
3. 확인 후 일괄 삭제

**안전 보장:**
- 메인 프로젝트는 절대 삭제 안 함
- 커밋 안 된 변경사항이 있는 worktree는 스킵

**예시 출력:**
```
변경사항 없는 worktree만 정리합니다
  메인 프로젝트는 절대 삭제 안 함

  ● feat/old-feature - 삭제 가능
  ● feat/ticket - 3개 변경 (스킵)

계속하시겠습니까? (y/N):
```

### `cw status` - 상태 확인

현재 프로젝트의 전체 상태를 확인합니다.

```bash
cw status
```

**출력 정보:**
- tmux 세션 상태 (실행/중지)
- 현재 브랜치
- worktree 목록
- tmux 윈도우 목록

## 실전 예시

### 시나리오 1: 기능 개발 중 긴급 버그 수정

```bash
# 1. 세션 시작 및 기능 개발 중
cd ~/projects/myapp
cw start
cw add feature feat/user-profile

# [3] feature 윈도우에서 작업 중...

# 2. 긴급 버그 발견!
# Ctrl+B, 1 - git 윈도우로 이동
cw add hotfix feat/critical-bug

# 3. Ctrl+B, 4 - hotfix 윈도우로 자동 이동
#    버그 수정 작업...

# 4. 버그 수정 완료
cw rm hotfix

# 5. Ctrl+B, 3 - feature 윈도우로 복귀
#    원래 작업 계속...
```

### 시나리오 2: 여러 기능 동시 개발

```bash
# 1. 세션 시작
cd ~/projects/myapp
cw start

# 2. 여러 워크플로우 추가
cw add auth feat/authentication
cw add payment feat/payment-integration
cw add ui feat/ui-redesign

# 3. 윈도우 전환하며 작업
#    Ctrl+B, 3 - auth
#    Ctrl+B, 4 - payment
#    Ctrl+B, 5 - ui

# 4. 상태 확인
cw status

# 5. 완료된 것부터 제거
cw rm auth
cw rm payment

# 6. 모든 작업 완료 후 세션 종료
cw stop
```

### 시나리오 3: 코드 리뷰 준비

```bash
# 1. 리뷰할 브랜치들을 각각 열기
cw start
cw add pr1 feat/feature-1
cw add pr2 feat/feature-2
cw add pr3 fix/bug-fix

# 2. 각 윈도우를 돌아다니며 코드 확인
#    Ctrl+B, w - 윈도우 목록 보기
#    Ctrl+B, 숫자 - 빠른 전환

# 3. 리뷰 완료 후 한 번에 정리
cw clean
```

### 시나리오 4: 테스트 환경 구성

```bash
# 1. 다양한 버전 동시 테스트
cw start
cw add v1 release/v1.0
cw add v2 release/v2.0
cw add dev feat/experimental

# 2. 각 버전에서 동일한 테스트 실행
#    윈도우 전환하며 결과 비교

# 3. 테스트 완료
cw stop
```

## 안전 정책

`cw`는 데이터 손실을 방지하기 위한 다중 안전 장치를 제공합니다.

### 1. 메인 프로젝트 보호

```bash
# 메인 프로젝트 디렉토리는 절대 삭제 불가
cw rm main
# ✗ 메인 프로젝트는 삭제 불가!
```

### 2. 변경사항 검사

```bash
# 커밋 안 된 변경사항이 있으면 삭제 차단
cw rm feature
# ✗ 커밋 안 된 변경사항 5개 있음!
#
#   해결 방법:
#     1. 먼저 커밋: cd /path && git add . && git commit
#     2. 강제 삭제: cw rm feature --force
```

### 3. 삭제 전 확인

```bash
# 항상 삭제 전 확인 질문
cw rm feature
#
#   삭제 대상: /Users/user/projects/myapp-feature
#
#   삭제하시겠습니까? (y/N):
```

### 4. 강제 삭제 플래그

```bash
# 강제 삭제는 명시적으로만 가능
cw rm feature --force

# 다른 표현은 인식 안 됨
cw rm feature -f        # ✗ 동작 안 함
cw rm feature --f       # ✗ 동작 안 함
```

## tmux 단축키

### 기본 단축키

| 단축키 | 기능 |
|--------|------|
| `Ctrl+B, 숫자` | 해당 번호 윈도우로 이동 |
| `Ctrl+B, w` | 윈도우 목록 보기 (화살표로 선택) |
| `Ctrl+B, n` | 다음 윈도우 |
| `Ctrl+B, p` | 이전 윈도우 |
| `Ctrl+B, c` | 새 윈도우 생성 |
| `Ctrl+B, ,` | 윈도우 이름 변경 |
| `Ctrl+B, d` | 세션 분리 (백그라운드) |
| `Ctrl+B, ?` | 모든 단축키 보기 |

### 실전 팁

```bash
# 빠른 윈도우 전환
Ctrl+B, 0    # main
Ctrl+B, 1    # git
Ctrl+B, 3    # feature

# 윈도우 목록 확인
Ctrl+B, w
# → 화살표 키로 이동 후 Enter

# 세션 백그라운드 실행
Ctrl+B, d
# → 터미널 닫아도 세션 유지
# → 나중에 cw attach로 복귀
```

## 문제 해결

### `cw: command not found`

**원인:** PATH에 ~/bin이 없음

**해결:**
```bash
# 1. PATH 추가
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 2. 실행 권한 확인
chmod +x ~/bin/cw

# 3. 다시 시도
cw --version
```

### `tmux 필요: brew install tmux`

**원인:** tmux가 설치되지 않음

**해결:**
```bash
# macOS
brew install tmux

# Ubuntu/Debian
sudo apt install tmux

# Fedora
sudo dnf install tmux

# 확인
tmux -V
```

### `Git 저장소가 아닙니다`

**원인:** Git 저장소가 아닌 디렉토리에서 실행

**해결:**
```bash
# 1. Git 저장소 확인
git status

# 2. Git 저장소 초기화 (필요한 경우)
git init

# 3. Git 저장소 디렉토리로 이동
cd ~/projects/myapp
```

### 의존성 설치 실패

**원인:** package.json이 없거나 패키지 매니저 문제

**해결:**
```bash
# 1. 수동으로 의존성 설치
cd /path/to/worktree

# pnpm
pnpm install

# yarn
yarn install

# npm
npm install

# 2. 다시 cw add 실행
```

### Worktree 이미 존재 경고

**원인:** 같은 이름의 worktree가 이미 있음

**해결:**
```bash
# 1. 목록 확인
cw ls

# 2. 기존 worktree 제거
cw rm <name>

# 3. 다시 추가
cw add <name>
```

### tmux 윈도우가 응답하지 않음

**원인:** Claude Code가 멈춤 또는 프로세스 충돌

**해결:**
```bash
# 1. 해당 윈도우에서 Ctrl+C
# 2. claude 재실행
claude

# 또는 윈도우 재생성
cw rm <name>
cw add <name>
```

## 업데이트 방법

새 버전이 나왔을 때:

### 방법 1: 스크립트로 설치한 경우

```bash
# 1. 최신 버전 다운로드
curl -o ~/bin/cw https://raw.githubusercontent.com/lu1ee/cw/main/cw
chmod +x ~/bin/cw

# 2. 확인
cw --version
```

### 방법 2: Git으로 설치한 경우

```bash
# 1. 저장소 업데이트
cd ~/bin/cw-cli
git pull origin main

# 2. 확인
cw --version
```

## 제거 방법

`cw`를 완전히 제거하려면:

```bash
# 1. 실행 중인 세션 종료
cw stop

# 2. 스크립트 삭제
rm ~/bin/cw

# 또는 Git으로 설치한 경우
rm -rf ~/bin/cw-cli
rm ~/bin/cw  # 심볼릭 링크 제거

# 3. 확인
cw --version
# cw: command not found
```

**주의:** worktree들은 자동으로 삭제되지 않습니다. 필요하면 수동으로 정리하세요:

```bash
# worktree 목록 확인
git worktree list

# worktree 제거
git worktree remove /path/to/worktree

# 또는 디렉토리 삭제
rm -rf /path/to/worktree
git worktree prune
```

## 팁과 요령

### 1. 쉘 함수로 더 편하게

`~/.zshrc`에 추가:

```bash
# 프로젝트로 빠르게 이동하고 세션 시작
cwstart() {
  cd "$1" && cw start
}

# 사용
cwstart ~/projects/myapp
```

### 2. 자동 완성

```bash
# cw 명령어 자동 완성 (bash/zsh)
complete -W "start add rm ls attach stop clean status" cw
```

### 3. tmux 설정 커스터마이즈

`~/.tmux.conf`:

```bash
# 윈도우 번호를 1부터 시작
set -g base-index 1

# 마우스 지원
set -g mouse on

# 상태바 커스터마이즈
set -g status-style bg=blue,fg=white
```

### 4. 브랜치 네이밍 컨벤션

```bash
# 일관된 브랜치 이름 사용
cw add auth feat/authentication
cw add fix fix/login-error
cw add hot hotfix/security-patch
cw add exp exp/new-architecture
```
