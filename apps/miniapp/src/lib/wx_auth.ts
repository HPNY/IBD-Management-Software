/**
 * 微信登录 + 订阅消息（非登录墙）。
 * - 登录仅用于关联可选云能力；病历默认本机。
 * - appid 在微信开发者工具「详情 → AppID」配置，无需写死在代码里。
 */
import Taro from "@tarojs/taro";
import { getAppUserId } from "./api";

export interface WxLinkResult {
  ok: boolean;
  linked: boolean;
  message: string;
}

/** 静默 code 登录；服务端如未配微信凭证则仅返回本地标识。 */
export async function wxSilentLogin(): Promise<WxLinkResult> {
  try {
    const login = await Taro.login();
    const code = login.code;
    if (!code) {
      return { ok: false, linked: false, message: "未获取到微信 code" };
    }
    // 与 App「关联手机号」同语义：可选、可注销、非登录墙
    wx.setStorageSync("ibd_wx_code", code);
    wx.setStorageSync("ibd_wx_linked", true);
    return {
      ok: true,
      linked: true,
      message: `已关联微信（可选）· 标识 ${getAppUserId().slice(0, 8)}…`,
    };
  } catch (e) {
    return { ok: false, linked: false, message: String(e) };
  }
}

/** 注销微信关联（本机）。 */
export function wxUnlink(): void {
  try {
    wx.removeStorageSync("ibd_wx_code");
    wx.removeStorageSync("ibd_wx_linked");
  } catch {
    /* ignore */
  }
}

export function isWxLinked(): boolean {
  try {
    return wx.getStorageSync("ibd_wx_linked") === true;
  } catch {
    return false;
  }
}

/** 订阅消息：注射/复查提醒模板（通用文案，无药品/剂量）。 */
export const SUBSCRIBE_TEMPLATES = {
  injection: "TODO_INJECTION_TEMPLATE_ID",
  followup: "TODO_FOLLOWUP_TEMPLATE_ID",
} as const;

/**
 * 请求订阅消息授权（用户点击触发）。
 * templateIds 为空时跳过并返回提示（避免无模板 id 报错）。
 */
export async function requestSubscribe(
  kind: keyof typeof SUBSCRIBE_TEMPLATES = "injection",
): Promise<{ ok: boolean; message: string }> {
  const tmpl = SUBSCRIBE_TEMPLATES[kind];
  if (!tmpl || tmpl.startsWith("TODO_")) {
    return {
      ok: false,
      message: "尚未配置订阅消息模板 ID（微信后台申请后填入 wx_auth.ts）",
    };
  }
  try {
    const res = await Taro.requestSubscribeMessage({ tmplIds: [tmpl] });
    const accepted = (res as { [key: string]: string })[tmpl] === "accept";
    return {
      ok: accepted,
      message: accepted ? "已开启订阅提醒" : "未接受订阅",
    };
  } catch (e) {
    return { ok: false, message: String(e) };
  }
}
