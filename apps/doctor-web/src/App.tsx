import { useCallback, useEffect, useState } from "react";

const API = "/api/v1";

type Me = {
  id: string;
  name: string;
  hospital?: string | null;
  reviewStatus: string;
};

async function api<T>(
  path: string,
  init?: RequestInit & { token?: string | null },
): Promise<T> {
  const { token, headers, ...rest } = init ?? {};
  const res = await fetch(`${API}${path}`, {
    ...rest,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(headers ?? {}),
    },
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`${res.status} ${text}`);
  }
  return (await res.json()) as T;
}

/** T6.2 M1–M2：医生端壳（登录/注册 · 授权码）。 */
export default function App() {
  const [token, setToken] = useState<string | null>(
    localStorage.getItem("doctor_token"),
  );
  const [me, setMe] = useState<Me | null>(null);
  const [msg, setMsg] = useState("");
  const [scope, setScope] = useState<string[]>(["labs", "symptoms"]);
  const [patients, setPatients] = useState<
    Array<{ grantId: string; patientId: string; scope: string[]; expiresAt: string }>
  >([]);
  const [detail, setDetail] = useState<Record<string, unknown> | null>(null);
  const [noteText, setNoteText] = useState("");
  const [qr, setQr] = useState<{ code: string; qrPayload: string; expiresAt: string } | null>(
    null,
  );
  const [form, setForm] = useState({
    name: "",
    email: "",
    password: "",
    hospital: "",
    licenseNo: "",
  });
  const [loginForm, setLoginForm] = useState({ email: "", password: "" });

  const loadMe = useCallback(async (t: string) => {
    try {
      const m = await api<Me>(`/doctor/me`, { token: t });
      setMe(m);
      setMsg("");
    } catch (e) {
      setMsg(String(e));
    }
  }, []);

  useEffect(() => {
    if (token) void loadMe(token);
  }, [token, loadMe]);

  const register = async () => {
    try {
      await api(`/doctor/register`, {
        method: "POST",
        body: JSON.stringify(form),
      });
      setMsg("已注册，待人工审核执业信息（pending）");
    } catch (e) {
      setMsg(String(e));
    }
  };

  const login = async () => {
    try {
      const r = await api<{ accessToken: string; doctor: Me }>(
        `/doctor/login`,
        {
          method: "POST",
          body: JSON.stringify(loginForm),
        },
      );
      localStorage.setItem("doctor_token", r.accessToken);
      setToken(r.accessToken);
      setMe(r.doctor);
    } catch (e) {
      setMsg(String(e));
    }
  };

  const loadPatients = async () => {
    if (!token) return;
    try {
      const r = await api<
        Array<{ grantId: string; patientId: string; scope: string[]; expiresAt: string }>
      >(`/doctor-data/patients`, { token });
      setPatients(r);
      setMsg("");
    } catch (e) {
      setMsg(String(e));
    }
  };

  const openDetail = async (grantId: string) => {
    if (!token) return;
    try {
      const d = await api<Record<string, unknown>>(
        `/doctor-data/grants/${grantId}`,
        { token },
      );
      setDetail(d);
    } catch (e) {
      setMsg(String(e));
    }
  };

  const addNote = async (grantId: string) => {
    if (!token || !noteText.trim()) return;
    try {
      await api(`/doctor-data/grants/${grantId}/notes`, {
        method: "POST",
        token,
        body: JSON.stringify({ content: noteText }),
      });
      setNoteText("");
      setMsg("已写入医学建议（患者可见）");
      await openDetail(grantId);
    } catch (e) {
      setMsg(String(e));
    }
  };

  const createCode = async () => {
    if (!token) return;
    try {
      const r = await api<{ code: string; qrPayload: string; expiresAt: string }>(
        `/doctor-grants/code`,
        {
          method: "POST",
          token,
          body: JSON.stringify({ scope, ttlHours: 24 }),
        },
      );
      setQr(r);
      setMsg("已生成授权码，请患者扫码确认");
    } catch (e) {
      setMsg(String(e));
    }
  };

  const toggleScope = (s: string) => {
    setScope((prev) =>
      prev.includes(s) ? prev.filter((x) => x !== s) : [...prev, s],
    );
  };

  return (
    <div className="shell">
      <h1>IBDers 医生端</h1>
      <p className="muted">
        仅查看患者主动授权的数据；授权可收回、可过期。执业核验一期为人工审核。
      </p>
      {msg && (
        <div className="card" style={{ background: "#fef3c7" }}>
          {msg}
        </div>
      )}

      {!token && (
        <>
          <div className="card">
            <h2>医生注册</h2>
            <input
              placeholder="姓名"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
            />
            <input
              placeholder="邮箱"
              value={form.email}
              onChange={(e) => setForm({ ...form, email: e.target.value })}
            />
            <input
              type="password"
              placeholder="密码（≥8）"
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
            />
            <input
              placeholder="医院（可选）"
              value={form.hospital}
              onChange={(e) => setForm({ ...form, hospital: e.target.value })}
            />
            <input
              placeholder="执业证号（可选）"
              value={form.licenseNo}
              onChange={(e) => setForm({ ...form, licenseNo: e.target.value })}
            />
            <button type="button" onClick={() => void register()}>
              注册
            </button>
          </div>
          <div className="card">
            <h2>登录</h2>
            <input
              placeholder="邮箱"
              value={loginForm.email}
              onChange={(e) =>
                setLoginForm({ ...loginForm, email: e.target.value })
              }
            />
            <input
              type="password"
              placeholder="密码"
              value={loginForm.password}
              onChange={(e) =>
                setLoginForm({ ...loginForm, password: e.target.value })
              }
            />
            <button type="button" onClick={() => void login()}>
              登录
            </button>
          </div>
        </>
      )}

      {token && me && (
        <div className="card">
          <h2>
            {me.name} · {me.hospital ?? "未填医院"}
          </h2>
          <p className="muted">审核状态：{me.reviewStatus}</p>
          <div className="row">
            <button
              type="button"
              className="ghost"
              onClick={() => {
                localStorage.removeItem("doctor_token");
                setToken(null);
                setMe(null);
                setQr(null);
              }}
            >
              退出
            </button>
          </div>
        </div>
      )}

      {token && me?.reviewStatus === "approved" && (
        <div className="card">
          <h2>生成患者授权码（M2）</h2>
          <p className="muted">
            勾选可查看范围（最小披露）。二维码内容见下方。
          </p>
          <div className="row">
            {["labs", "symptoms", "alerts", "summary"].map((s) => (
              <label key={s} style={{ marginRight: 8 }}>
                <input
                  type="checkbox"
                  checked={scope.includes(s)}
                  onChange={() => toggleScope(s)}
                />{" "}
                {s}
              </label>
            ))}
          </div>
          <button type="button" onClick={() => void createCode()}>
            生成授权码
          </button>
          {qr && (
            <pre
              style={{
                background: "#f8fafc",
                padding: 12,
                borderRadius: 8,
                overflowX: "auto",
              }}
            >
              {qr.qrPayload}
              {"\n"}
              code={qr.code} {"\n"}过期 {qr.expiresAt}
            </pre>
          )}
        </div>
      )}

      <div className="card">
        <h2>授权患者列表（M3）</h2>
        <button type="button" onClick={() => void loadPatients()}>
          刷新列表
        </button>
        <ul>
          {patients.map((p) => (
            <li key={p.grantId}>
              <button
                type="button"
                className="ghost"
                onClick={() => void openDetail(p.grantId)}
              >
                {p.patientId.slice(0, 8)} · {p.scope.join("/")}
              </button>
            </li>
          ))}
          {patients.length === 0 && (
            <li className="muted">暂无已确认授权</li>
          )}
        </ul>
      </div>
      {detail && (
        <div className="card">
          <h2>患者详情</h2>
          <pre style={{ whiteSpace: "pre-wrap" }}>
            {JSON.stringify(detail, null, 2)}
          </pre>
          <input
            placeholder="医学建议（如：建议下次复查钙卫蛋白）"
            value={noteText}
            onChange={(e) => setNoteText(e.target.value)}
          />
          <button
            type="button"
            onClick={() => void addNote(String(detail.grantId))}
          >
            保存建议
          </button>
        </div>
      )}
    </div>
  );
}
