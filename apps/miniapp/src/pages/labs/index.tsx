import { useCallback, useEffect, useState } from "react";
import { View, Text } from "@tarojs/components";
import { CORE_LAB_NAMES } from "@ibd/domain-types";
import { api } from "../../lib/api";
import "./index.scss";

export default function Labs() {
  const [rows, setRows] = useState<
    Array<{ nameNorm: string; value: number; unit?: string; date: string }>
  >([]);
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setErr(null);
    try {
      const labs = (await api().listLabs()) as Array<{
        date: string;
        items: Array<{ nameNorm: string; value: number; unit?: string }>;
      }>;
      const flat = labs.flatMap((l) =>
        (l.items ?? []).map((it) => ({
          nameNorm: it.nameNorm,
          value: it.value,
          unit: it.unit,
          date: l.date,
        })),
      );
      const core = flat.filter((r) =>
        (CORE_LAB_NAMES as readonly string[]).includes(r.nameNorm),
      );
      setRows(core.slice(0, 40));
    } catch (e) {
      setErr(String(e));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  return (
    <View className="page">
      <Text className="h">最近检验（核心指标）</Text>
      {loading && <Text className="muted">加载中…</Text>}
      {err && <Text className="err">需连后端：{err}</Text>}
      {!loading && !err && rows.length === 0 && (
        <Text className="muted">暂无数据 · 请在 App 录入或解析</Text>
      )}
      {rows.map((r, i) => (
        <View key={i} className="row">
          <Text className="name">{r.nameNorm}</Text>
          <Text className="val">
            {r.value}
            {r.unit ? ` ${r.unit}` : ""} · {r.date}
          </Text>
        </View>
      ))}
    </View>
  );
}
