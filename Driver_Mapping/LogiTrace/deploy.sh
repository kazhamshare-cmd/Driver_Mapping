#!/bin/bash

# LogiTrace デプロイスクリプト
# 使用方法: ./deploy.sh <server_ip> <ssh_user>

set -e

SERVER_IP=$1
SSH_USER=$2

if [ -z "$SERVER_IP" ] || [ -z "$SSH_USER" ]; then
    echo "使用方法: ./deploy.sh <server_ip> <ssh_user>"
    echo "例: ./deploy.sh 52.69.62.236 ubuntu"
    exit 1
fi

echo "================================================"
echo "LogiTrace デプロイ開始"
echo "サーバー: $SSH_USER@$SERVER_IP"
echo "================================================"

# ローカルビルド
echo ""
echo "[1/5] ローカルビルド中..."

# フロントエンドビルド
echo "  - フロントエンドビルド..."
cd web-dashboard
npm install --silent
npm run build
cd ..

# バックエンドビルド
echo "  - バックエンドビルド..."
cd backend
npm install --silent
npm run build
cd ..

echo "  ✓ ビルド完了"

# サーバーディレクトリ作成
echo ""
echo "[2/5] サーバー準備中..."
ssh $SSH_USER@$SERVER_IP "sudo mkdir -p /var/www/logitrace/{backend,frontend,database,uploads/pdfs} && sudo chown -R $SSH_USER:$SSH_USER /var/www/logitrace"

echo "  ✓ ディレクトリ準備完了"

# ファイルアップロード
echo ""
echo "[3/5] ファイルアップロード中..."

# バックエンド
echo "  - バックエンドアップロード..."
rsync -avz --delete \
    --exclude 'node_modules' \
    --exclude '.env' \
    backend/ $SSH_USER@$SERVER_IP:/var/www/logitrace/backend/

# フロントエンド
echo "  - フロントエンドアップロード..."
rsync -avz --delete \
    web-dashboard/dist/ $SSH_USER@$SERVER_IP:/var/www/logitrace/frontend/

# データベーススキーマ
echo "  - データベーススキーマアップロード..."
rsync -avz \
    database/ $SSH_USER@$SERVER_IP:/var/www/logitrace/database/

echo "  ✓ アップロード完了"

# サーバーで依存関係インストール
echo ""
echo "[4/5] サーバーセットアップ中..."
ssh $SSH_USER@$SERVER_IP << 'REMOTE_SCRIPT'
cd /var/www/logitrace/backend
npm install --production --silent

# .envファイルが存在しない場合は作成
if [ ! -f .env ]; then
    echo "PORT=3000" > .env
    echo "DATABASE_URL=postgresql://logitrace:password@localhost:5432/logitrace" >> .env
    echo "JWT_SECRET=$(openssl rand -hex 32)" >> .env
    echo "NODE_ENV=production" >> .env
    echo "注意: .envファイルを作成しました。DATABASE_URLを正しい値に更新してください。"
fi
REMOTE_SCRIPT

echo "  ✓ セットアップ完了"

# PM2 再起動
echo ""
echo "[5/5] サービス再起動中..."
ssh $SSH_USER@$SERVER_IP << 'REMOTE_SCRIPT'
cd /var/www/logitrace/backend

# PM2がインストールされていない場合はインストール
if ! command -v pm2 &> /dev/null; then
    sudo npm install -g pm2
fi

# プロセスが存在するか確認
if pm2 list | grep -q "logitrace-api"; then
    pm2 restart logitrace-api
else
    pm2 start dist/index.js --name logitrace-api
    pm2 save
fi
REMOTE_SCRIPT

echo "  ✓ サービス再起動完了"

echo ""
echo "================================================"
echo "デプロイ完了！"
echo ""
echo "アクセス URL:"
echo "  - Web: http://$SERVER_IP"
echo "  - API: http://$SERVER_IP/api"
echo ""
echo "次のステップ:"
echo "  1. サーバーで .env ファイルを確認・更新"
echo "  2. データベーススキーマを適用（初回のみ）:"
echo "     psql -U logitrace -d logitrace -f /var/www/logitrace/database/schema.sql"
echo "  3. Nginx設定を適用（初回のみ）:"
echo "     DEPLOYMENT.md を参照"
echo "================================================"
