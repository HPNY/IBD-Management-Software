import { useState } from "react";
import * as XLSX from "xlsx";

const KEYS = {
  labs: "ibd_web_labs",
  clinical: "ibd_web_clinical",
};

export default function DataExport() {
  const [msg, setMsg] = useState<string | null>(null);

  const collect = () => {
    const labs = JSON.parse(localStorage.getItem(KEYS.labs) || "[]");
    const clinical = JSON.parse(localStorage.getItem(KEYS.clinical) || "[]");
    return {
      exportedAt: new Date().toISOString(),
      source: "ibd-web",
      labs,
      clinical,
    };
  };

  const exportJson = () => {
    const blob = new Blob([JSON.stringify(collect(), null, 2)], {
      type: "application/json",
    });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `ibders-export-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    setMsg("已导出 JSON");
  };

  const exportCsv = () => {
    const data = collect();
    const rows: string[] = ["type,date,name,value,unit,note"];
    for (const l of data.labs as Array<{
      date: string;
      items: Array<{ nameNorm: string; value: number; unit?: string }>;
    }>) {
      for (const it of l.items || []) {
        rows.push(
          `lab,${l.date},${it.nameNorm},${it.value},${it.unit ?? ""},`,
        );
      }
    }
    for (const c of data.clinical as Array<{
      kind: string;
      date: string;
      type: string;
      conclusion: string;
    }>) {
      rows.push(`clinical,${c.date},${c.type},,,${c.conclusion}`);
    }
    const blob = new Blob(["﻿" + rows.join("\n")], { type: "text/csv" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `ibders-export-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    setMsg("已导出 CSV");
  };

  const exportExcel = () => {
    const data = collect();
    const labRows: Array<{
      date: string;
      nameNorm: string;
      value: number;
      unit?: string;
    }> = [];
    for (const l of data.labs as Array<{
      date: string;
      items: Array<{ nameNorm: string; value: number; unit?: string }>;
    }>) {
      for (const it of l.items || []) {
        labRows.push({
          date: l.date,
          nameNorm: it.nameNorm,
          value: it.value,
          unit: it.unit,
        });
      }
    }
    const clinicalRows = data.clinical as Array<{
      kind: string;
      date: string;
      type: string;
      conclusion: string;
    }>;

    const wb = XLSX.utils.book_new();
    const labsSheet = XLSX.utils.json_to_sheet(labRows, {
      header: ["date", "nameNorm", "value", "unit"],
    });
    const clinicalSheet = XLSX.utils.json_to_sheet(clinicalRows, {
      header: ["kind", "date", "type", "conclusion"],
    });
    XLSX.utils.book_append_sheet(wb, labsSheet, "labs");
    XLSX.utils.book_append_sheet(wb, clinicalSheet, "clinical");
    XLSX.writeFile(
      wb,
      `ibders-export-${new Date().toISOString().slice(0, 10)}.xlsx`,
    );
    setMsg("已导出 Excel");
  };

  const importJson = (file: File | null) => {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const data = JSON.parse(String(reader.result));
        if (data.labs) localStorage.setItem(KEYS.labs, JSON.stringify(data.labs));
        if (data.clinical)
          localStorage.setItem(KEYS.clinical, JSON.stringify(data.clinical));
        setMsg("已导入到本机");
      } catch (e) {
        setMsg(`导入失败：${e}`);
      }
    };
    reader.readAsText(file);
  };

  const printSummary = () => {
    const data = collect();
    const w = window.open("", "_blank");
    if (!w) return;
    w.document.write(
      `<html><head><title>IBDers 就诊摘要</title></head><body><h1>IBDers 就诊摘要</h1><pre>${JSON.stringify(data, null, 2)}</pre></body></html>`,
    );
    w.document.close();
    w.print();
    setMsg("已打开打印视图");
  };

  return (
    <div>
      <h1>数据 / 报告导出</h1>
      <p className="hint">
        JSON / CSV / Excel 导出 · 导入换机 · 摘要打印。数据默认仅本机。
      </p>
      <div className="card">
        <div className="row">
          <button onClick={exportJson}>导出 JSON</button>
          <button onClick={exportCsv}>导出 CSV</button>
          <button onClick={exportExcel}>导出 Excel</button>
          <button className="ghost" onClick={printSummary}>
            打印就诊摘要
          </button>
          <label>
            导入 JSON{" "}
            <input
              type="file"
              accept=".json"
              onChange={(e) => importJson(e.target.files?.[0] ?? null)}
            />
          </label>
        </div>
        {msg && <div className="msg">{msg}</div>}
      </div>
    </div>
  );
}
