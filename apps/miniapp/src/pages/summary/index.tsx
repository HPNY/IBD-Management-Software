import { useState } from "react";
import { View, Text, Button } from "@tarojs/components";
import Taro from "@tarojs/taro";
import { getAppUserId } from "../../lib/api";
import "./index.scss";

export default function Summary() {
  const uid = getAppUserId();
  const [text] = useState(() => {
    const date = new Date().toISOString().slice(0, 10);
    const checkins = (wx.getStorageSync("ibd_mini_checkins") as unknown[]) ?? [];
    const last = checkins[0] as
      | { painLevel?: number; bowelCount?: number; overallFeeling?: string }
      | undefined;
    return [
      "IBDers 就诊摘要（小程序轻量版）",
      `日期：${date}`,
      `标识：${uid}`,
      last
        ? `最近打卡：腹痛 ${last.painLevel ?? "-"} · 排便 ${last.bowelCount ?? "-"} · 整体 ${last.overallFeeling ?? "-"}`
        : "最近打卡：暂无",
      "说明：完整病程、检验趋势与预警请在 App 导出。病历默认只在本机。",
    ].join("\n");
  });

  const share = async () => {
    try {
      await Taro.setClipboardData({ data: text });
      void Taro.showToast({ title: "已复制摘要", icon: "success" });
    } catch (e) {
      void Taro.showToast({ title: String(e), icon: "none" });
    }
  };

  return (
    <View className="page">
      <Text className="h">就诊摘要</Text>
      <View className="card">
        <Text className="body">{text}</Text>
      </View>
      <Button type="primary" onClick={share}>
        复制摘要分享
      </Button>
      <Text className="muted">不含原始 PDF · 分享前请自行核对</Text>
    </View>
  );
}
