import { useEffect, useMemo, useState } from "react";
import ReactECharts from "echarts-for-react";
import { CORE_LAB_NAMES, type LabItem } from "@ibd/domain-types";

const RANGES = [
  { key: "3m", label: "近 3 月", days: 90 },
  { key: "1y", label: "近 1 年", days: 365 },
  { key: "all", label: "全部", days: 0 },
];

interface LabRecord {
  id: string;
  date: string;
  items: LabItem[];
}

export default function Trends() {
  const [range, setRange] = useState("1y");
  const [selected, setSelected] = useState<string[]>([
    "超敏C反应蛋白",
    "粪便钙卫蛋白",
  ]);
  const [labs, setLabs] = useState<LabRecord[]>([]);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    const raw = localStorage.getItem("ibd_web_labs");
    if (raw) {
      try {
        setLabs(JSON.parse(raw) as LabRecord[]);
      } catch {
        /* ignore */
      }
    }
  }, []);

  const filtered = useMemo(() => {
    const r = RANGES.find((x) => x.key === range)!;
    if (!r.days) return labs;
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - r.days);
    return labs.filter((l) => new Date(l.date) >= cutoff);
  }, [labs, range]);

  const option = useMemo(() => {
    const dates = filtered.map((l) => l.date).sort();
    const series = selected.map((name) => ({
      name,
      type: "line" as const,
      smooth: true,
      showSymbol: true,
      data: dates.map((d) => {
        const rec = filtered.find((l) => l.date === d);
        const item = rec?.items.find((i) => i.nameNorm === name);
        return item ? item.value : null;
      }),
    }));
    return {
      tooltip: { trigger: "axis" },
      legend: { data: selected },
      grid: { left: 48, right: 24, top: 40, bottom: 40 },
      xAxis: { type: "category", data: dates },
      yAxis: { type: "value", scale: true },
      series,
    };
  }, [filtered, selected]);

  const toggle = (name: string) => {
    setSelected((prev) =>
      prev.includes(name) ? prev.filter((n) => n !== name) : [...prev, name],
    );
  };

  return (
    <div>
      <h1>趋势分析</h1>
      <p className="hint">
        多指标叠加 · 时间范围筛选。数据来自本机/导入的检验记录（domain-types
        核心指标）。
      </p>

      <div className="card">
        <div className="row">
          {RANGES.map((r) => (
            <span
              key={r.key}
              className={range === r.key ? "chip on" : "chip"}
              onClick={() => setRange(r.key)}
            >
              {r.label}
            </span>
          ))}
        </div>
        <div className="chips">
          {CORE_LAB_NAMES.map((n) => (
            <span
              key={n}
              className={selected.includes(n) ? "chip on" : "chip"}
              onClick={() => toggle(n)}
            >
              {n}
            </span>
          ))}
        </div>
      </div>

      <div className="card">
        {err && <div className="msg err">{err}</div>}
        {filtered.length === 0 ? (
          <div className="msg">
            暂无数据 · 可在「数据导出」页导入 JSON，或从 App 同步
          </div>
        ) : (
          <ReactECharts option={option} className="chart" notMerge />
        )}
      </div>
    </div>
  );
}
