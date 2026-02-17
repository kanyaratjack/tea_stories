const DEFAULT_FOLDER = "products";
const PRESIGN_TTL_SECONDS = 10 * 60;

export default {
  async fetch(request, env) {
    try {
      if (request.method === "OPTIONS") {
        return new Response(null, { status: 204, headers: corsHeaders() });
      }

      const url = new URL(request.url);
      const pathname = url.pathname;

      if (request.method === "POST" && pathname === "/api/uploads/presign") {
        await verifyApiToken(request, env);
        return await handlePresign(request, url, env);
      }

      if (request.method === "PUT" && pathname === "/api/uploads/upload") {
        return await handleUpload(request, url, env);
      }

      if (request.method === "GET" && pathname.startsWith("/files/")) {
        return await handleFileGet(url, env);
      }

      return json({ error: "Not found" }, 404);
    } catch (error) {
      return json({ error: error.message || String(error) }, 400);
    }
  },
};

async function handlePresign(request, url, env) {
  const body = await parseJson(request);
  const fileName = String(body.fileName || "").trim();
  const folderInput = String(body.folder || DEFAULT_FOLDER).trim();
  const folder = sanitizeFolder(folderInput);
  const ext = normalizeExt(fileName);
  const objectKey =
    folder +
    "/" +
    Date.now().toString() +
    "_" +
    crypto.randomUUID().replace(/-/g, "").slice(0, 12) +
    ext;
  const exp = Math.floor(Date.now() / 1000) + PRESIGN_TTL_SECONDS;
  const sig = await signUploadKey(objectKey, exp, env);
  const uploadUrl =
    url.origin +
    "/api/uploads/upload?key=" +
    encodeURIComponent(objectKey) +
    "&exp=" +
    exp.toString() +
    "&sig=" +
    encodeURIComponent(sig);
  const publicBase = (env.PUBLIC_BASE_URL || "").trim();
  const publicUrl =
    (publicBase ? trimSlash(publicBase) : url.origin) +
    "/files/" +
    encodeURIComponent(objectKey);
  return json(
    {
      data: {
        uploadUrl,
        publicUrl,
        objectKey,
      },
    },
    200,
  );
}

async function handleUpload(request, url, env) {
  const key = String(url.searchParams.get("key") || "").trim();
  const expRaw = String(url.searchParams.get("exp") || "").trim();
  const sig = String(url.searchParams.get("sig") || "").trim();
  if (!key || !expRaw || !sig) {
    throw new Error("Missing key/exp/sig.");
  }
  const exp = Number(expRaw);
  if (!Number.isFinite(exp) || exp <= 0) {
    throw new Error("Invalid exp.");
  }
  const now = Math.floor(Date.now() / 1000);
  if (exp < now) {
    throw new Error("Upload URL expired.");
  }
  const expectedSig = await signUploadKey(key, exp, env);
  if (!constantTimeEqual(expectedSig, sig)) {
    throw new Error("Invalid upload signature.");
  }
  const contentType =
    request.headers.get("content-type") || "application/octet-stream";
  const body = request.body;
  if (!body) {
    throw new Error("Empty request body.");
  }
  await env.PRODUCT_IMAGES.put(key, body, {
    httpMetadata: { contentType },
  });
  return json({ ok: true }, 200);
}

async function handleFileGet(url, env) {
  const key = decodeURIComponent(url.pathname.replace("/files/", ""));
  if (!key) {
    return json({ error: "Missing file key." }, 400);
  }
  const obj = await env.PRODUCT_IMAGES.get(key);
  if (!obj) {
    return json({ error: "File not found." }, 404);
  }
  const headers = new Headers(corsHeaders());
  obj.writeHttpMetadata(headers);
  headers.set("etag", obj.httpEtag);
  headers.set("cache-control", "public, max-age=86400");
  return new Response(obj.body, { status: 200, headers });
}

async function parseJson(request) {
  const text = await request.text();
  if (!text.trim()) return {};
  try {
    return JSON.parse(text);
  } catch (_) {
    throw new Error("Invalid JSON.");
  }
}

function normalizeExt(fileName) {
  const lower = fileName.toLowerCase();
  if (lower.endsWith(".png")) return ".png";
  if (lower.endsWith(".webp")) return ".webp";
  if (lower.endsWith(".gif")) return ".gif";
  if (lower.endsWith(".jpeg")) return ".jpeg";
  if (lower.endsWith(".jpg")) return ".jpg";
  return ".jpg";
}

function sanitizeFolder(folder) {
  const cleaned = folder
    .replace(/[^a-zA-Z0-9/_-]/g, "")
    .replace(/^\/+/, "")
    .replace(/\/+$/, "");
  return cleaned || DEFAULT_FOLDER;
}

async function verifyApiToken(request, env) {
  const token = (env.UPLOAD_API_TOKEN || "").trim();
  if (!token) return;
  const auth = request.headers.get("authorization") || "";
  const xApiKey = request.headers.get("x-api-key") || "";
  const bearer = auth.toLowerCase().startsWith("bearer ")
    ? auth.slice(7).trim()
    : "";
  const incoming = bearer || xApiKey.trim();
  if (!incoming || !constantTimeEqual(incoming, token)) {
    throw new Error("Unauthorized.");
  }
}

async function signUploadKey(key, exp, env) {
  const secret = (env.UPLOAD_SIGNING_SECRET || "").trim();
  if (!secret) {
    throw new Error("Missing UPLOAD_SIGNING_SECRET.");
  }
  const payload = key + "|" + String(exp);
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    new TextEncoder().encode(payload),
  );
  return base64Url(new Uint8Array(signature));
}

function base64Url(bytes) {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function constantTimeEqual(a, b) {
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let i = 0; i < a.length; i += 1) {
    mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return mismatch === 0;
}

function trimSlash(input) {
  return input.replace(/\/+$/, "");
}

function corsHeaders() {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,POST,PUT,OPTIONS",
    "access-control-allow-headers": "Content-Type,Authorization,X-Api-Key",
  };
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: {
      ...corsHeaders(),
      "content-type": "application/json; charset=utf-8",
    },
  });
}

