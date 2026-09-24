import { useEffect, useState } from "react";

interface Record {
  id: string;
  kind: "exam" | "surgery";
  type: string;
  date: string;
  hospital: string;
  findings: string;
  conclusion: string;
  notes: string;
}

const KEY = "ibd_web_clinical";

const empty = (): Record => ({
  id: "",
  kind: "exam",
  type: "超声",
  date: new Date().toISOString().slice(0, 10),
  hospital: "",
  findings: "",
  conclusion: "",
  notes: "",
});

export default function ClinicalEdit() {
  const [list, setList] = useState<Record[]>([]);
  const [form, setForm] = useState<Record>(empty());
  const [msg, setMsg] = useState<string | null>(null);

  useEffect(() => {
    const raw = localStorage.getItem(KEY);
    if (raw) {
      try {
        setList(JSON.parse(raw) as Record[]);
      } catch {
        /* ignore */
      }
    }
  }, []);

  const persist = (next: Record[]) => {
    setList(next);
    localStorage.setItem(KEY, JSON.stringify(next));
  };

  const save = () => {
    const rec: Record = {
      ...form,
      id: form.id || `c-${Date.now()}`,
    };
    const next = form.id
      ? list.map((x) => (x.id === form.id ? rec : x))
      : [rec, ...list];
    persist(next);
    setForm(empty());
    setMsg("已保存到本机");
  };

  const edit = (r: Record) => setForm(r);
  const remove = (id: string) => persist(list.filter((x) => x.id !== id));

  return (
    <div>
      <h1>检查 / 手术编辑</h1>
      <p className="hint">比 App 更完整的表单：检查所见、结论、备注均可编辑。</p>

      <div className="card">
        <div className="row">
          <label>
            类型{" "}
            <select
              value={form.kind}
              onChange={(e) =>
                setForm({ ...form, kind: e.target.value as Record["kind"] })
              }
            >
              <option value="exam">检查</option>
              <option value="surgery">手术</option>
            </select>
          </label>
          <label>
            项目{" "}
            <input
              value={form.type}
              onChange={(e) => setForm({ ...form, type: e.target.value })}
              placeholder="超声 / 内镜 / 术式"
            />
          </label>
          <label>
            日期{" "}
            <input
              type="date"
              value={form.date}
              onChange={(e) => setForm({ ...form, date: e.target.value })}
            />
          </label>
          <label>
            医院{" "}
            <input
              value={form.hospital}
              onChange={(e) => setForm({ ...form, hospital: e.target.value })}
            />
          </label>
        </div>
        <div className="row" style={{ flexDirection: "column", alignItems: "stretch" }}>
          <label>所见</label>
          <textarea
            value={form.findings}
            onChange={(e) => setForm({ ...form, findings: e.target.value })}
          />
          <label>结论</label>
          <textarea
            value={form.conclusion}
            onChange={(e) => setForm({ ...form, conclusion: e.target.value })}
          />
          <label>备注</label>
          <textarea
            value={form.notes}
            onChange={(e) => setForm({ ...form, notes: e.target.value })}
          />
        </div>
        <div className="row">
          <button onClick={save}>{form.id ? "更新" : "新增"}</button>
          {form.id && (
            <button className="ghost" onClick={() => setForm(empty())}>
              取消编辑
            </button>
          )}
          {msg && <span className="msg">{msg}</span>}
        </div>
      </div>

      <div className="card">
        <table>
          <thead>
            <tr>
              <th>类型</th>
              <th>项目</th>
              <th>日期</th>
              <th>医院</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            {list.map((r) => (
              <tr key={r.id}>
                <td>{r.kind === "exam" ? "检查" : "手术"}</td>
                <td>{r.type}</td>
                <td>{r.date}</td>
                <td>{r.hospital}</td>
                <td>
                  <button className="ghost" onClick={() => edit(r)}>
                    编辑
                  </button>{" "}
                  <button className="ghost" onClick={() => remove(r.id)}>
                    删除
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
