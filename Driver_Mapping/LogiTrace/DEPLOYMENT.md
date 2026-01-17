# LogiTrace サーバーデプロイ手順

## 概要
Docker不使用、直接 Node.js + Nginx + PM2 でのデプロイ手順

## サーバー要件
- Ubuntu 22.04 LTS
- 2GB RAM以上推奨
- Node.js 20 LTS
- PostgreSQL 15
- Nginx

---

## 1. サーバー初期設定

### 1.1 システムアップデート
```bash
sudo apt update && sudo apt upgrade -y
```

### 1.2 必要なパッケージのインストール
```bash
# Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Nginx
sudo apt install -y nginx

# その他
sudo apt install -y git curl
```

### 1.3 PM2 インストール（プロセスマネージャー）
```bash
sudo npm install -g pm2
```

---

## 2. PostgreSQL 設定

### 2.1 データベース作成
```bash
sudo -u postgres psql
```

```sql
CREATE USER logitrace WITH PASSWORD 'your_secure_password';
CREATE DATABASE logitrace OWNER logitrace;
GRANT ALL PRIVILEGES ON DATABASE logitrace TO logitrace;
\q
```

### 2.2 スキーマ適用
```bash
psql -U logitrace -d logitrace -f /var/www/logitrace/database/schema.sql
```

---

## 3. アプリケーションデプロイ

### 3.1 ディレクトリ作成
```bash
sudo mkdir -p /var/www/logitrace
sudo chown -R $USER:$USER /var/www/logitrace
```

### 3.2 ファイルアップロード
ローカルから以下のディレクトリをアップロード:
- `backend/` → `/var/www/logitrace/backend/`
- `web-dashboard/dist/` → `/var/www/logitrace/frontend/`
- `database/` → `/var/www/logitrace/database/`

```bash
# ローカルから実行（例）
scp -r backend/ user@server:/var/www/logitrace/
scp -r web-dashboard/dist/* user@server:/var/www/logitrace/frontend/
scp -r database/ user@server:/var/www/logitrace/
```

### 3.3 バックエンド設定

```bash
cd /var/www/logitrace/backend

# 依存関係インストール
npm install --production

# 環境変数設定
cat > .env << 'EOF'
PORT=3000
DATABASE_URL=postgresql://logitrace:your_secure_password@localhost:5432/logitrace
JWT_SECRET=your_jwt_secret_key_here
NODE_ENV=production
EOF

# TypeScript ビルド
npm run build
```

### 3.4 PM2 でバックエンド起動
```bash
cd /var/www/logitrace/backend
pm2 start dist/index.js --name logitrace-api

# 自動起動設定
pm2 startup
pm2 save
```

---

## 4. Nginx 設定

### 4.1 設定ファイル作成
```bash
sudo nano /etc/nginx/sites-available/logitrace
```

```nginx
server {
    listen 80;
    server_name your_domain.com;

    # フロントエンド（静的ファイル）
    location / {
        root /var/www/logitrace/frontend;
        try_files $uri $uri/ /index.html;

        # キャッシュ設定
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # バックエンドAPI
    location /api/ {
        rewrite ^/api/(.*) /$1 break;
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_cache_bypass $http_upgrade;
    }

    # 認証エンドポイント
    location /auth/ {
        rewrite ^/auth/(.*) /auth/$1 break;
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # PDF アップロード・ダウンロード
    location /uploads/ {
        alias /var/www/logitrace/backend/uploads/;
        expires 1d;
    }

    # セキュリティヘッダー
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
```

### 4.2 設定有効化
```bash
sudo ln -s /etc/nginx/sites-available/logitrace /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## 5. HTTPS 設定（Let's Encrypt）

```bash
# Certbot インストール
sudo apt install -y certbot python3-certbot-nginx

# 証明書取得
sudo certbot --nginx -d your_domain.com

# 自動更新テスト
sudo certbot renew --dry-run
```

---

## 6. ファイアウォール設定

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

---

## 7. 運用コマンド

### サービス状態確認
```bash
# PM2 ステータス
pm2 status

# ログ確認
pm2 logs logitrace-api

# Nginx ステータス
sudo systemctl status nginx

# PostgreSQL ステータス
sudo systemctl status postgresql
```

### 再起動
```bash
# バックエンドのみ
pm2 restart logitrace-api

# Nginx
sudo systemctl restart nginx

# 全体
pm2 restart all && sudo systemctl restart nginx
```

### アップデート手順
```bash
cd /var/www/logitrace/backend
git pull  # または新しいファイルをアップロード
npm install --production
npm run build
pm2 restart logitrace-api
```

---

## 8. バックアップ

### データベースバックアップ
```bash
# 手動バックアップ
pg_dump -U logitrace logitrace > backup_$(date +%Y%m%d).sql

# 自動バックアップ（crontab設定）
0 3 * * * pg_dump -U logitrace logitrace > /var/backups/logitrace/backup_$(date +\%Y\%m\%d).sql
```

---

## 9. トラブルシューティング

### バックエンドが起動しない
```bash
# ログ確認
pm2 logs logitrace-api --lines 100

# 手動起動でエラー確認
cd /var/www/logitrace/backend
node dist/index.js
```

### 502 Bad Gateway
```bash
# PM2 プロセス確認
pm2 status

# Nginx エラーログ
sudo tail -f /var/log/nginx/error.log
```

### データベース接続エラー
```bash
# PostgreSQL 状態確認
sudo systemctl status postgresql

# 接続テスト
psql -U logitrace -d logitrace -c "SELECT 1;"
```

---

## 10. 環境変数一覧

| 変数名 | 説明 | 例 |
|--------|------|-----|
| PORT | バックエンドポート | 3000 |
| DATABASE_URL | PostgreSQL接続文字列 | postgresql://user:pass@localhost:5432/db |
| JWT_SECRET | JWT署名キー | ランダム文字列 |
| NODE_ENV | 環境 | production |

---

## 付録: ローカルビルドコマンド

### フロントエンドビルド
```bash
cd web-dashboard
npm install
npm run build
# dist/ フォルダをサーバーにアップロード
```

### バックエンドビルド
```bash
cd backend
npm install
npm run build
# dist/ フォルダをサーバーにアップロード
```

### モバイルアプリビルド
```bash
cd mobile-app
npm install
npx expo build:android  # Android
npx expo build:ios      # iOS
```
