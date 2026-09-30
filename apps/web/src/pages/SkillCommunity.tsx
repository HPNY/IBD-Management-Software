import { useCallback, useEffect, useMemo, useState } from "react";
import type { ParseSkill, ParseSkillItemRule } from "@ibd/domain-types";

const STORAGE_KEY = "ibd_web_skills";

type CommunitySummary = {
  id: string;
  hospital: string;
  reportType: string;
  currentVersion: string | null;
  usageCount: number;
  ratingAvg: number | null;
  ratingCount: number;
  composite: number;
};

function loadLocal(): ParseSkill[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? (parsed as ParseSkill[]) : [];
  } catch {
    return [];
  }
}

function persistLocal(next: ParseSkill[]) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
}

/** C1.2 前端预检（服务端 scrub 为权威）。 */
function localScrubErrors(skill: ParseSkill): string[] {
  const errors: string[] = [];
  const blob = JSON.stringify(skill);
  if (/\b1[3-9]\d{9}\b/.test(blob)) errors.push("疑似手机号");
  if (/\b\d{17}[\dXx]\b/.test(blob)) errors.push("疑似身份证");
  if (/病[案历]号|住院号/.test(blob)) errors.push("疑似病案/住院号");
  return errors;
}

const apiBase =
  (import.meta as { env?: { VITE_API_BASE?: string } }).env?.VITE_API_BASE ??
  "http://127.0.0.1:3000/api/v1";

async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${apiBase}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`${res.status} ${body}`);
  }
  return (await res.json()) as T;
}

/** T6.1：Skill 社区（匿名发布 / 浏览 / 评分 / 协作）。 */
export default function SkillCommunity() {
  const [list, setList] = useState<CommunitySummary[]>([]);
  const [q, setQ] = useState("");
  const [msg, setMsg] = useState("");
  const [busy, setBusy] = useState(false);
  const [selected, setSelected] = useState<CommunitySummary | null>(null);
  const [score, setScore] = useState(5);
  const [comment, setComment] = useState("");
  const [detail, setDetail] = useState<{
    versions: {
      id: string;
      version: string;
      parentVersion: string | null;
      itemCount: number;
      usageCount: number;
    }[];
  } | null>(null);

  const refresh = useCallback(async () => {
    setBusy(true);
    try {
      const data = await api<CommunitySummary[]>(
        `/skill-community/skills${q ? `?q=${encodeURIComponent(q)}` : ""}`,
      );
      setList(data);
      setMsg("");
    } catch (e) {
      setMsg(`社区加载失败（可离线仅用本地模板）：${e}`);
      setList([]);
    } finally {
      setBusy(false);
    }
  }, [q]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const localSkills = useMemo(() => loadLocal(), [msg, selected]);

  const publishLocal = async (skill: ParseSkill) => {
    const errs = localScrubErrors(skill);
    if (errs.length) {
      setMsg(`发布前检查未通过：${errs.join("；")}`);
      return;
    }
    setBusy(true);
    try {
      const payload = {
        hospital: skill.hospital,
        reportType: skill.reportType,
        version: skill.version || "1.0.0",
        dateExtraction: skill.dateExtraction,
        items: skill.items.map((it: ParseSkillItemRule) => ({
          name: it.name,
          pattern: it.pattern,
          ...(it.alias ? { alias: it.alias } : {}),
          ...(it.unit ? { unit: it.unit } : {}),
          ...(it.refRange ? { refRange: it.refRange } : {}),
          ...(it.multiline !== undefined ? { multiline: it.multiline } : {}),
        })),
      };
      await api("/skill-community/skills", {
        method: "POST",
        body: JSON.stringify({ skill: payload }),
      });
      setMsg(`已发布：${skill.hospital} · ${skill.reportType}`);
      await refresh();
    } catch (e) {
      setMsg(`发布失败：${e}`);
    } finally {
      setBusy(false);
    }
  };

  const importSelected = () => {
    if (!selected) return;
    setBusy(true);
    void (async () => {
      try {
        const content = await api<{
          hospital: string;
          reportType: string;
          version: string;
          dateExtraction: ParseSkill["dateExtraction"];
          items: ParseSkillItemRule[];
        }>(`/skill-community/skills/${selected.id}/content`);
        const imported: ParseSkill = {
          hospital: content.hospital,
          reportType: content.reportType,
          version: content.version,
          dateExtraction: content.dateExtraction ?? { primary: "" },
          items: content.items ?? [],
        };
        const next = loadLocal();
        next.push(imported);
        persistLocal(next);
        setMsg(`已导入本地：${imported.hospital} · ${imported.reportType}`);
      } catch (e) {
        setMsg(`导入失败：${e}`);
      } finally {
        setBusy(false);
      }
    })();
  };

  const submitRating = async () => {
    if (!selected) return;
    setBusy(true);
    try {
      await api(`/skill-community/skills/${selected.id}/ratings`, {
        method: "POST",
        body: JSON.stringify({ score, comment: comment || undefined }),
      });
      setMsg("已评分");
      setComment("");
      await refresh();
    } catch (e) {
      setMsg(`评分失败：${e}`);
    } finally {
      setBusy(false);
    }
  };

  const loadDetail = async (s: CommunitySummary) => {
    setSelected(s);
    try {
      const d = await api<{
        versions: {
          id: string;
          version: string;
          parentVersion: string | null;
          itemCount: number;
          usageCount: number;
        }[];
      }>(`/skill-community/skills/${s.id}`);
      setDetail(d);
    } catch (e) {
      setMsg(String(e));
    }
  };

  return (
    <div style={{ padding: 24, maxWidth: 880, margin: "0 auto" }}>
      <h1>Skill 社区</h1>
      <p style={{ color: "#64748B", fontSize: 13 }}>
        匿名分享医院报告解析模板（仅 Skill 规则 JSON，不含原始病历/报告）。发布前会做脱敏检查。
      </p>

      <div style={{ display: "flex", gap: 8, marginBottom: 12 }}>
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="搜索医院 / 报告类型"
          style={{ flex: 1, padding: 8, borderRadius: 8, border: "1px solid #CBD5E1" }}
        />
        <button type="button" onClick={() => void refresh()} disabled={busy}>
          刷新
        </button>
      </div>

      {msg && (
        <div className="msg" style={{ marginBottom: 12, fontSize: 13 }}>
          {msg}
        </div>
      )}

      <h2 style={{ fontSize: 16 }}>社区模板</h2>
      {list.length === 0 && (
        <div className="msg">暂无社区模板（可从下方本地模板发布）</div>
      )}
      <ul style={{ listStyle: "none", padding: 0 }}>
        {list.map((s) => (
          <li
            key={s.id}
            style={{
              border: "1px solid #E2E8F0",
              borderRadius: 12,
              padding: 12,
              marginBottom: 8,
            }}
          >
            <div style={{ fontWeight: 700 }}>
              {s.hospital} · {s.reportType}
            </div>
            <div style={{ fontSize: 12.5, color: "#64748B" }}>
              v{s.currentVersion ?? "—"} · 使用 {s.usageCount} · 评分{" "}
              {s.ratingAvg ?? "—"}（{s.ratingCount}）· 综合 {s.composite}
            </div>
            <div style={{ marginTop: 8, display: "flex", gap: 8 }}>
              <button type="button" onClick={() => void loadDetail(s)}>
                详情
              </button>
              <button type="button" onClick={importSelected}>
                导入本地
              </button>
            </div>
          </li>
        ))}
      </ul>

      {selected && detail && (
        <section style={{ marginTop: 16 }}>
          <h2 style={{ fontSize: 16 }}>
            详情 · {selected.hospital} · {selected.reportType}
          </h2>
          <ul>
            {detail.versions.map((v) => (
              <li key={v.id} style={{ fontSize: 13 }}>
                v{v.version}
                {v.parentVersion ? ` ← ${v.parentVersion}` : ""} · items{" "}
                {v.itemCount} · 使用 {v.usageCount}
              </li>
            ))}
          </ul>
          <div style={{ display: "flex", gap: 8, alignItems: "center", marginTop: 8 }}>
            <label>
              评分{" "}
              <select value={score} onChange={(e) => setScore(Number(e.target.value))}>
                {[5, 4, 3, 2, 1].map((n) => (
                  <option key={n} value={n}>
                    {n} 星
                  </option>
                ))}
              </select>
            </label>
            <input
              value={comment}
              onChange={(e) => setComment(e.target.value)}
              placeholder="短评（可选，≤500 字）"
              style={{ flex: 1, padding: 6, borderRadius: 8, border: "1px solid #CBD5E1" }}
            />
            <button type="button" onClick={() => void submitRating()} disabled={busy}>
              提交评分
            </button>
          </div>
        </section>
      )}

      <h2 style={{ fontSize: 16, marginTop: 24 }}>我的本地模板（可发布）</h2>
      <ul style={{ listStyle: "none", padding: 0 }}>
        {localSkills.map((s, i) => (
          <li
            key={`${s.hospital}-${s.reportType}-${i}`}
            style={{
              border: "1px solid #E2E8F0",
              borderRadius: 12,
              padding: 12,
              marginBottom: 8,
            }}
          >
            <div style={{ fontWeight: 700 }}>
              {s.hospital} · {s.reportType}
            </div>
            <div style={{ fontSize: 12.5, color: "#64748B" }}>
              v{s.version} · items {s.items?.length ?? 0}
            </div>
            <button
              type="button"
              style={{ marginTop: 8 }}
              disabled={busy}
              onClick={() => void publishLocal(s)}
            >
              发布到社区（匿名）
            </button>
          </li>
        ))}
        {localSkills.length === 0 && (
          <li className="msg">先到「Skill 模板」保存本地模板</li>
        )}
      </ul>

      <p style={{ fontSize: 12, color: "#64748B" }}>
        不替代医生建议；社区评分仅供参考。请勿在模板中写入真实病历信息。
      </p>
    </div>
  );
}
