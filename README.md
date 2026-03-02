# teaStore Monorepo

本仓库已拆分为 3 个独立项目：

## 1) 移动端（Flutter）

路径：`/Users/jack/teaStore/mobile-app`

```bash
cd /Users/jack/teaStore/mobile-app
flutter pub get
flutter run
```

## 2) 后端（Go + PostgreSQL）

路径：`/Users/jack/teaStore/backend/go-api`

```bash
cd /Users/jack/teaStore/backend/go-api
export DATABASE_URL="postgres://postgres:postgres@localhost:5432/tea_store?sslmode=disable"
go run ./cmd/server
```

## 3) 前端管理台（JS 静态）

路径：`/Users/jack/teaStore/web-admin`

```bash
cd /Users/jack/teaStore/web-admin
python3 -m http.server 5173
```

打开：

- [http://127.0.0.1:5173](http://127.0.0.1:5173)

在页面顶部填 API Base URL（例如 `http://192.168.1.37:8080`）。

---

说明：后端已开启 CORS，支持独立前端跨域调用。

## 一键启动（推荐）

```bash
cd /Users/jack/teaStore
./scripts/dev-up.sh
```

这条命令会：

- 后台启动 Go 后端（8080）
- 后台启动 web-admin（5173）
- 前台执行 `flutter run`

停止后台服务：

```bash
cd /Users/jack/teaStore
./scripts/dev-down.sh
```
