import { useState } from "react";
import { View, Text } from "@tarojs/components";
import "./index.scss";

interface Shot {
  drug: string;
  plannedDate: string;
  weekNumber: number;
}

export default function Injection() {
  const [list] = useState<Shot[]>(() => {
    try {
      const raw = wx.getStorageSync("ibd_mini_injections") as Shot[];
      return raw?.length ? raw : [];
    } catch {
      return [];
    }
  });

  return (
    <View className="page">
      <Text className="h">注射提醒</Text>
      {list.length === 0 ? (
        <View className="card">
          <Text className="muted">暂无本机排期。完整排期与提醒请在 App 中查看和管理。</Text>
        </View>
      ) : (
        list.map((s, i) => (
          <View key={i} className="row">
            <Text className="drug">{s.drug}</Text>
            <Text className="date">
              第 {s.weekNumber} 针 · {s.plannedDate}
            </Text>
          </View>
        ))
      )}
      <Text className="muted">完整排期与提醒请在 App 中管理</Text>
    </View>
  );
}
