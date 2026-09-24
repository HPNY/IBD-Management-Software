import { useState } from "react";
import { View, Text, Picker, Button, Slider } from "@tarojs/components";
import Taro from "@tarojs/taro";
import type { SymptomDiary, BristolType } from "@ibd/domain-types";
import "./index.scss";

const BRISTOL = ["1", "2", "3", "4", "5", "6", "7"];

export default function Checkin() {
  const [pain, setPain] = useState(0);
  const [bowel, setBowel] = useState(1);
  const [stoolIdx, setStoolIdx] = useState(3);
  const [feeling, setFeeling] = useState<SymptomDiary["overallFeeling"]>("same");

  const save = () => {
    const diary: Partial<SymptomDiary> = {
      date: new Date().toISOString().slice(0, 10),
      painLevel: pain,
      bowelCount: bowel,
      stoolType: (stoolIdx + 1) as BristolType,
      overallFeeling: feeling,
    };
    const key = "ibd_mini_checkins";
    const list = (wx.getStorageSync(key) as unknown[]) ?? [];
    wx.setStorageSync(key, [diary, ...list]);
    void Taro.showToast({ title: "已保存到本机", icon: "success" });
  };

  return (
    <View className="page">
      <Text className="h">简化打卡（本机）</Text>
      <View className="field">
        <Text>腹痛 0–10：{pain}</Text>
        <Slider
          min={0}
          max={10}
          value={pain}
          onChange={(e) => setPain(e.detail.value)}
        />
      </View>
      <View className="field">
        <Text>排便次数：{bowel}</Text>
        <Slider
          min={0}
          max={15}
          value={bowel}
          onChange={(e) => setBowel(e.detail.value)}
        />
      </View>
      <Picker
        mode="selector"
        range={BRISTOL.map((n) => `${n} 型`)}
        value={stoolIdx}
        onChange={(e) => setStoolIdx(Number(e.detail.value))}
      >
        <View className="picker">Bristol：{BRISTOL[stoolIdx]} 型</View>
      </Picker>
      <View className="feeling">
        {(["better", "same", "worse"] as const).map((f) => (
          <Text
            key={f}
            className={feeling === f ? "chip on" : "chip"}
            onClick={() => setFeeling(f)}
          >
            {f === "better" ? "好转" : f === "same" ? "差不多" : "变差"}
          </Text>
        ))}
      </View>
      <Button type="primary" onClick={save}>
        保存打卡
      </Button>
    </View>
  );
}
