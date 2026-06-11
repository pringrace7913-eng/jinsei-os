#!/bin/bash
# 人生OS PWA → GitHub Pages 公開スクリプト（固定URL＋QR発行まで全自動）
# 使い方:  bash deploy.sh
set -e
REPO="jinsei-os"
cd "$(dirname "$0")"

echo "==================================================="
echo " 人生OS を GitHub Pages に公開します"
echo "==================================================="

# 1) GitHub ログイン確認（未ログインなら案内に従ってブラウザでログイン）
if ! gh auth status >/dev/null 2>&1; then
  echo ""
  echo "▶ GitHub にログインします。画面の質問にこう答えてください:"
  echo "    ? What account do you want to log into?      → GitHub.com"
  echo "    ? What is your preferred protocol ...?        → HTTPS"
  echo "    ? Authenticate Git with your GitHub creds?    → Yes"
  echo "    ? How would you like to authenticate?         → Login with a web browser"
  echo "  → 表示される8桁コードをコピー → Enter → ブラウザで貼り付け → Authorize"
  echo ""
  gh auth login
fi

USER=$(gh api user --jq .login)
echo "▶ ログイン中のアカウント: $USER"

# 2) リポジトリ作成＆push（既にあれば push のみ）
if gh repo view "$USER/$REPO" >/dev/null 2>&1; then
  echo "▶ リポジトリ $USER/$REPO は既存。最新を push します。"
  git add -A
  git commit -q -m "update" || true
  git push -q
else
  echo "▶ リポジトリ $USER/$REPO を新規作成して push します。"
  git branch -M main
  gh repo create "$REPO" --public --source=. --remote=origin --push
fi

# 3) GitHub Pages を有効化（main ブランチのルート）
echo "▶ GitHub Pages を有効化します..."
gh api -X POST "repos/$USER/$REPO/pages" -f "source[branch]=main" -f "source[path]=/" >/dev/null 2>&1 \
  || gh api -X PUT "repos/$USER/$REPO/pages" -f "source[branch]=main" -f "source[path]=/" >/dev/null 2>&1 \
  || echo "  （Pages は既に有効、または手動設定が必要な場合があります）"

URL="https://$USER.github.io/$REPO/"
echo ""
echo "==================================================="
echo " 固定URL: $URL"
echo " （反映に最大1〜2分かかります）"
echo "==================================================="

# 4) QRコード生成（segno を使える環境を用意）
PYBIN="python3"
if ! python3 -c "import segno" >/dev/null 2>&1; then
  if [ ! -d .qrvenv ]; then python3 -m venv .qrvenv; fi
  ./.qrvenv/bin/pip install --quiet segno >/dev/null 2>&1
  PYBIN="./.qrvenv/bin/python"
fi
"$PYBIN" - "$URL" <<'PY'
import sys, segno
url=sys.argv[1]
qr=segno.make(url, error='h')
qr.save("jinsei-os-qr.png", scale=12, border=4, dark="#0a1430", light="#ffffff")
qr.save("jinsei-os-qr.svg", scale=12, border=4, dark="#0a1430", light="#ffffff")
print("▶ QRを生成しました: jinsei-os-qr.png / jinsei-os-qr.svg")
PY

echo ""
echo "完了。jinsei-os-qr.png をカメラで読めば $URL が開きます。"
echo "（このフォルダ: $(pwd) ）"
