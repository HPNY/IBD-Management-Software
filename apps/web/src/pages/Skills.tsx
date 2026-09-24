import { useEffect, useState } from "react";
import type { ParseSkill, ParseSkillItemRule } from "@ibd/domain-types";

const STORAGE_KEY = "ibd_web_skills";

interface ItemRow {
  name: string;
  alias: string;
  pattern: string;
  unit: string;
  refMin: string;
  refMax: string;
  multiline?: boolean;
}

interface FormState {
  hospital: string;
  reportType: string;
  version: string;
  datePrimary: string;
  dateFallback: string;
  items: ItemRow[];
}

function emptyForm(): FormState {
  return {
    hospital: "",
    reportType: "",
    version: "",
    datePrimary: "",
    dateFallback: "",
    items: [{ name: "", alias: "", pattern: "", unit: "", refMin: "", refMax: "" }],
  };
}

function skillToForm(skill: ParseSkill): FormState {
  return {
    hospital: skill.hospital,
    reportType: skill.reportType,
    version: skill.version,
    datePrimary: skill.dateExtraction?.primary ?? "",
    dateFallback: skill.dateExtraction?.fallback ?? "",
    items: (skill.items ?? []).map((it) => ({
      name: it.name ?? "",
      alias: it.alias ?? "",
      pattern: it.pattern ?? "",
      unit: it.unit ?? "",
      refMin: it.refRange ? String(it.refRange[0]) : "",
      refMax: it.refRange ? String(it.refRange[1]) : "",
      multiline: it.multiline,
    })),
  };
}

function formToSkill(form: FormState): ParseSkill {
  const items: ParseSkillItemRule[] = form.items.map((r) => {
    const rule: ParseSkillItemRule = {
      name: r.name.trim(),
      pattern: r.pattern.trim(),
    };
    if (r.alias.trim()) rule.alias = r.alias.trim();
    if (r.unit.trim()) rule.unit = r.unit.trim();
    const min = Number(r.refMin);
    const max = Number(r.refMax);
    if (r.refMin.trim() !== "" && r.refMax.trim() !== "" && !Number.isNaN(min) && !Number.isNaN(max)) {
      rule.refRange = [min, max];
    }
    if (r.multiline !== undefined) rule.multiline = r.multiline;
    return rule;
  });
  const skill: ParseSkill = {
    hospital: form.hospital.trim(),
    reportType: form.reportType.trim(),
    version: form.version.trim(),
    dateExtraction: {
      primary: form.datePrimary.trim(),
      ...(form.dateFallback.trim() ? { fallback: form.dateFallback.trim() } : {}),
    },
    items,
  };
  return skill;
}

function validate(form: FormState): string[] {
  const errors: string[] = [];
  if (!form.hospital.trim()) errors.push("医院（hospital）不能为空");
  if (!form.reportType.trim()) errors.push("报告类型（reportType）不能为空");
  if (form.items.length < 1) errors.push("至少需要 1 条解析项（item）");
  form.items.forEach((it, i) => {
    if (!it.name.trim()) errors.push(`第 ${i + 1} 条：name 不能为空`);
    if (!it.pattern.trim()) errors.push(`第 ${i + 1} 条：pattern 不能为空`);
    const minFilled = it.refMin.trim() !== "";
    const maxFilled = it.refMax.trim() !== "";
    if (minFilled !== maxFilled) {
      errors.push(`第 ${i + 1} 条：refMin 与 refMax 需同时填写`);
    } else if (minFilled && (Number.isNaN(Number(it.refMin)) || Number.isNaN(Number(it.refMax)))) {
      errors.push(`第 ${i + 1} 条：refMin/refMax 必须是数字`);
    }
  });
  return errors;
}

function loadSkills(): ParseSkill[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? (parsed as ParseSkill[]) : [];
  } catch {
    return [];
  }
}

export default function Skills() {
  const [skills, setSkills] = useState<ParseSkill[]>([]);
  const [selectedIdx, setSelectedIdx] = useState<number | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm);
  const [errors, setErrors] = useState<string[]>([]);
  const [msg, setMsg] = useState<string | null>(null);

  useEffect(() => {
    setSkills(loadSkills());
  }, []);

  const persist = (next: ParseSkill[]) => {
    setSkills(next);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
  };

  const selectSkill = (idx: number) => {
    setSelectedIdx(idx);
    setForm(skillToForm(skills[idx]));
    setErrors([]);
    setMsg(null);
  };

  const newSkill = () => {
    setSelectedIdx(null);
    setForm(emptyForm());
    setErrors([]);
    setMsg(null);
  };

  const save = () => {
    const errs = validate(form);
    setErrors(errs);
    if (errs.length > 0) {
      setMsg(null);
      return;
    }
    const skill = formToSkill(form);
    let idx = selectedIdx;
    const next = [...skills];
    if (idx === null) {
      next.push(skill);
      idx = next.length - 1;
    } else {
      next[idx] = skill;
    }
    persist(next);
    setSelectedIdx(idx);
    setForm(skillToForm(skill));
    setMsg("已保存模板");
  };

  const remove = () => {
    if (selectedIdx === null) {
      setErrors(["请先选择要删除的模板"]);
      return;
    }
    const next = skills.filter((_, i) => i !== selectedIdx);
    persist(next);
    setSelectedIdx(null);
    setForm(emptyForm());
    setErrors([]);
    setMsg("已删除模板");
  };

  const exportOne = () => {
    const errs = validate(form);
    setErrors(errs);
    if (errs.length > 0) {
      setMsg(null);
      return;
    }
    const skill = formToSkill(form);
    const blob = new Blob([JSON.stringify(skill, null, 2)], {
      type: "application/json",
    });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    const safe = (s: string) => s.replace(/[^\w.-]+/g, "_") || "skill";
    a.download = `ibd-skill-${safe(skill.hospital)}-${safe(skill.reportType)}.json`;
    a.click();
    setMsg("已导出模板 JSON");
  };

  const importOne = (file: File | null) => {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const data = JSON.parse(String(reader.result));
        const skill: unknown = Array.isArray(data) ? data[0] : data;
        if (!skill || typeof skill !== "object") throw new Error("格式不正确");
        const s = skill as ParseSkill;
        if (typeof s.hospital !== "string" || typeof s.reportType !== "string") {
          throw new Error("缺少 hospital/reportType 字段");
        }
        const normalized: ParseSkill = {
          hospital: s.hospital.trim(),
          reportType: s.reportType.trim(),
          version: typeof s.version === "string" ? s.version : "",
          dateExtraction: {
            primary: s.dateExtraction?.primary ?? "",
            ...(s.dateExtraction?.fallback ? { fallback: s.dateExtraction.fallback } : {}),
          },
          items: Array.isArray(s.items)
            ? s.items.filter(
                (it): it is ParseSkillItemRule =>
                  !!it &&
                  typeof it === "object" &&
                  typeof (it as ParseSkillItemRule).name === "string" &&
                  typeof (it as ParseSkillItemRule).pattern === "string",
              )
            : [],
        };
        const importErrors = validate(skillToForm(normalized));
        if (importErrors.length > 0) {
          setErrors(importErrors);
          setMsg(null);
          return;
        }
        const next = [...skills, normalized];
        persist(next);
        setSelectedIdx(next.length - 1);
        setForm(skillToForm(normalized));
        setErrors([]);
        setMsg("已导入模板");
      } catch (e) {
        setErrors([`导入失败：${e instanceof Error ? e.message : String(e)}`]);
        setMsg(null);
      }
    };
    reader.readAsText(file);
  };

  const updateItem = (idx: number, patch: Partial<ItemRow>) => {
    setForm((f) => ({
      ...f,
      items: f.items.map((it, i) => (i === idx ? { ...it, ...patch } : it)),
    }));
  };

  const addItem = () => {
    setForm((f) => ({
      ...f,
      items: [
        ...f.items,
        { name: "", alias: "", pattern: "", unit: "", refMin: "", refMax: "" },
      ],
    }));
  };

  const removeItem = (idx: number) => {
    setForm((f) => ({ ...f, items: f.items.filter((_, i) => i !== idx) }));
  };

  return (
    <div>
      <h1>Skill 模板</h1>
      <p className="hint">
        解析 Skill 模板管理：新建 / 编辑 / 删除 / 导出 JSON / 导入 JSON。数据存于本机
        localStorage。
      </p>
      <div style={{ display: "grid", gridTemplateColumns: "280px 1fr", gap: 16, alignItems: "start" }}>
        <div className="card">
          <div className="row">
            <button className="ghost" onClick={newSkill}>
              新建模板
            </button>
          </div>
          {skills.length === 0 && <div className="msg">暂无已保存模板</div>}
          <ul style={{ listStyle: "none", margin: 0, padding: 0 }}>
            {skills.map((s, i) => (
              <li key={i}>
                <button
                  className={i === selectedIdx ? "" : "ghost"}
                  style={{
                    width: "100%",
                    textAlign: "left",
                    margin: "4px 0",
                    padding: "8px 12px",
                  }}
                  onClick={() => selectSkill(i)}
                >
                  {s.hospital} · {s.reportType} · {s.version || "—"}
                </button>
              </li>
            ))}
          </ul>
          {msg && <div className="msg">{msg}</div>}
        </div>

        <div className="card">
          <div className="row">
            <label>
              医院 hospital{" "}
              <input
                type="text"
                value={form.hospital}
                onChange={(e) => setForm((f) => ({ ...f, hospital: e.target.value }))}
              />
            </label>
            <label>
              报告类型 reportType{" "}
              <input
                type="text"
                value={form.reportType}
                onChange={(e) => setForm((f) => ({ ...f, reportType: e.target.value }))}
              />
            </label>
            <label>
              版本 version{" "}
              <input
                type="text"
                value={form.version}
                onChange={(e) => setForm((f) => ({ ...f, version: e.target.value }))}
              />
            </label>
          </div>
          <div className="row">
            <label>
              日期主正则 primary{" "}
              <input
                type="text"
                value={form.datePrimary}
                onChange={(e) =>
                  setForm((f) => ({ ...f, datePrimary: e.target.value }))
                }
              />
            </label>
            <label>
              日期备用正则 fallback（可选）{" "}
              <input
                type="text"
                value={form.dateFallback}
                onChange={(e) =>
                  setForm((f) => ({ ...f, dateFallback: e.target.value }))
                }
              />
            </label>
          </div>

          <h2 style={{ fontSize: 15, margin: "12px 0 8px" }}>解析项 items</h2>
          {form.items.map((it, idx) => (
            <div
              key={idx}
              className="row"
              style={{ border: "1px solid var(--line)", borderRadius: 8, padding: 10, marginBottom: 8 }}
            >
              <label>
                name{" "}
                <input
                  type="text"
                  value={it.name}
                  onChange={(e) => updateItem(idx, { name: e.target.value })}
                />
              </label>
              <label>
                alias{" "}
                <input
                  type="text"
                  value={it.alias}
                  onChange={(e) => updateItem(idx, { alias: e.target.value })}
                />
              </label>
              <label>
                pattern{" "}
                <input
                  type="text"
                  style={{ minWidth: 220 }}
                  value={it.pattern}
                  onChange={(e) => updateItem(idx, { pattern: e.target.value })}
                />
              </label>
              <label>
                unit{" "}
                <input
                  type="text"
                  value={it.unit}
                  onChange={(e) => updateItem(idx, { unit: e.target.value })}
                />
              </label>
              <label>
                refMin{" "}
                <input
                  type="text"
                  style={{ minWidth: 70 }}
                  value={it.refMin}
                  onChange={(e) => updateItem(idx, { refMin: e.target.value })}
                />
              </label>
              <label>
                refMax{" "}
                <input
                  type="text"
                  style={{ minWidth: 70 }}
                  value={it.refMax}
                  onChange={(e) => updateItem(idx, { refMax: e.target.value })}
                />
              </label>
              <button className="ghost" onClick={() => removeItem(idx)}>
                删除行
              </button>
            </div>
          ))}
          <div className="row">
            <button className="ghost" onClick={addItem}>
              添加解析项
            </button>
          </div>

          <div className="row">
            <button onClick={save}>保存</button>
            <button className="ghost" onClick={remove} disabled={selectedIdx === null}>
              删除
            </button>
            <button className="ghost" onClick={exportOne}>
              导出 JSON
            </button>
            <label>
              导入 JSON{" "}
              <input
                type="file"
                accept=".json"
                onChange={(e) => importOne(e.target.files?.[0] ?? null)}
              />
            </label>
          </div>
          {errors.map((err, i) => (
            <div key={i} className="msg err">
              {err}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
