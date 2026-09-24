import { useState } from "react";
import { View, Text } from "@tarojs/components";
import "./index.scss";

interface Shot {
  drug: string;
  plannedDate: string;
  weekNumber: number;
}

function today() {
  return new Date().toISOString().slice(0, 10);
}
function addDays(n: number) {
  const d = new Date();
  d.setDate(d.getDate() + n);
  return d.toISOString().slice(0, 10);
}

const DEMO: Shot[] = [
  { drug: "利生奇珠", plannedDate: today(), weekNumber: 2 },
  { drug: "利生奇珠", plannedDate: addDays(14), weekNumber: 3 },
];

export default function Injection() {
  const [list] = useState<Shot[]>(() => {
    try {
      const raw = wx.getStorageSync("ibd_mini_injections") as Shot[];
      return raw?.length ? raw : DEMO;
    } catch {
      return DEMO;
    }
  });

  return (
    <View className="page">
      <Text className="h">注射提醒</Text>
      {list.map((s, i) => (
        <View key={i} className="row">
          <Text className="drug">{s.drug}</Text>
          <Text className="date">
            第 {s.weekNumber} 针 · {s.plannedDate}
          </Text>
        </View>
      ))}
      <Text className="muted">完整排期与提醒请在 App 中管理</Text>
    </View>
  );
}
