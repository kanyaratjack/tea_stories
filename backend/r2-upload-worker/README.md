# R2 Upload Worker (for teaStore)

This Worker provides three endpoints:

1. `POST /api/uploads/presign`
2. `PUT /api/uploads/upload?key=...&exp=...&sig=...`
3. `GET /files/<objectKey>`

It is compatible with the Flutter client already added in this project (`lib/services/image_upload_service.dart`).

## 1) Prerequisites

- Cloudflare account
- R2 bucket created (example: `tea-store-product-images`)
- Node.js installed
- Wrangler CLI installed: `npm i -g wrangler`

## 2) Configure bucket binding

Edit `/Users/jack/teaStore/backend/r2-upload-worker/wrangler.toml` and make sure:

- `bucket_name` matches your real R2 bucket name.

## 3) Set secrets

Run in `/Users/jack/teaStore/backend/r2-upload-worker`:

```bash
wrangler secret put UPLOAD_SIGNING_SECRET
```

Optional (recommended) API token for presign endpoint:

```bash
wrangler secret put UPLOAD_API_TOKEN
```

Optional public base URL (if you use custom domain):

```bash
wrangler secret put PUBLIC_BASE_URL
```

If not set, the Worker origin is used.

## 4) Deploy

```bash
cd /Users/jack/teaStore/backend/r2-upload-worker
wrangler deploy
```

After deploy you get a URL such as:

`https://tea-store-r2-upload.<subdomain>.workers.dev`

## 5) Connect Flutter app

In app Settings page, set:

`Upload API Base URL = https://tea-store-r2-upload.<subdomain>.workers.dev`

Then in Product Management:

- click `选择并上传图片`
- upload succeeds
- image URL is auto-filled and saved to product `imageUrl`

## 6) Presign request example

```bash
curl -X POST "https://<worker-domain>/api/uploads/presign" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <UPLOAD_API_TOKEN>" \
  -d '{"fileName":"milk-tea.jpg","contentType":"image/jpeg","folder":"products"}'
```

Expected response:

```json
{
  "data": {
    "uploadUrl": "https://.../api/uploads/upload?key=...&exp=...&sig=...",
    "publicUrl": "https://.../files/products/....jpg",
    "objectKey": "products/....jpg"
  }
}
```

