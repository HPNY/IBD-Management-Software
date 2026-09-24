import { View, Text } from "@tarojs/components";
import Taro from "@tarojs/taro";
import { getAppUserId } from "../../lib/api";
import "./index.scss";

export default function Index() {
  const uid = getAppUserId();
  const go = (url: string) => Taro.switchTab({ url });
  return (
    <View className="page">
      <View className="hero">
        <Text className="title">IBDers 小程序</Text>
        <Text className="sub">轻量入口 · 病历仍在 App 本机</Text>
        <Text className="uid">标识 {uid.slice(0, 12)}…</Text>
      </View>
      <View className="cards">
        <View className="card" onClick={() => go("/pages/labs/index")}>
          <Text className="card-title">检验查看</Text>
          <Text className="card-sub">最近指标</Text>
        </View>
        <View className="card" onClick={() => go("/pages/checkin/index")}>
          <Text className="card-title">简化打卡</Text>
          <Text className="card-sub">腹痛 / 排便 / 整体</Text>
        </View>
        <View className="card" onClick={() => go("/pages/injection/index")}>
          <Text className="card-title">注射提醒</Text>
          <Text className="card-sub">今日 / 近期针次</Text>
        </View>
        <View className="card" onClick={() => go("/pages/summary/index")}>
          <Text className="card-title">就诊摘要</Text>
          <Text className="card-sub">分享给医生</Text>
        </View>
      </View>
    </View>
  );
}
