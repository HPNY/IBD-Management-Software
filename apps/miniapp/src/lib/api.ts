import { createClient } from "@ibd/api-client";

export const MINIAPP_API_BASE = process.env.IBD_API_BASE ?? "http://127.0.0.1:3000";

let _appUserId: string | null = null;
let _token: string | null = null;

export function getAppUserId(): string {
  if (_appUserId) return _appUserId;
  try {
    const cached = wx.getStorageSync("ibd_app_user_uuid") as string;
    if (cached) {
      _appUserId = cached;
      return cached;
    }
  } catch {
    /* ignore */
  }
  const uuid = `wx-${Date.now().toString(16)}-${Math.random().toString(16).slice(2, 10)}`;
  try {
    wx.setStorageSync("ibd_app_user_uuid", uuid);
  } catch {
    /* ignore */
  }
  _appUserId = uuid;
  return uuid;
}

export function api() {
  return createClient({
    baseUrl: MINIAPP_API_BASE,
    appUserId: getAppUserId(),
    fetchImpl: (input, init) =>
      new Promise((resolve, reject) => {
        wx.request({
          url: String(input),
          method: (init?.method as WechatMiniprogram.RequestOption["method"]) ?? "GET",
          header: (init?.headers as Record<string, string>) ?? {},
          data: init?.body ? JSON.parse(String(init.body)) : undefined,
          success: (res) => {
            resolve({
              ok: res.statusCode >= 200 && res.statusCode < 300,
              status: res.statusCode,
              text: async () => JSON.stringify(res.data),
              json: async () => res.data,
            } as Response);
          },
          fail: reject,
        });
      }) as Promise<Response>,
  });
}

/**
 * H23：受保护接口（如 /labs）需要 Bearer token。
 * 小程序此前直接调 listLabs，从不取 token → 永远 401。
 * 这里先换短时解析会话，再复用 token。
 */
export async function apiWithSession() {
  const client = api();
  if (!_token) {
    const session = await client.parseSession();
    _token = session.accessToken;
  }
  client.setToken(_token);
  return client;
}
