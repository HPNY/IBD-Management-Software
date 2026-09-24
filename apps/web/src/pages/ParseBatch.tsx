import { useRef, useState } from "react";
import { createClient, type IbdApiClient, type LabItemDto } from "@ibd/api-client";

interface FileTask {
  file: File;
  name: string;
  status: "pending" | "uploading" | "parsing" | "done" | "failed";
  jobId?: string;
  items?: LabItemDto[];
  error?: string;
}

/** 批量 PDF 解析：presign → PUT → enqueue → 轮询 → confirm（用完即删） */
export default function ParseBatch() {
  const [tasks, setTasks] = useState<FileTask[]>([]);
  const [hospital, setHospital] = useState("");
  const [reportType, setReportType] = useState("血常规");
  const [msg, setMsg] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const fileInput = useRef<HTMLInputElement>(null);

  const patch = (name: string, p: Partial<FileTask>) =>
    setTasks((prev) => prev.map((t) => (t.name === name ? { ...t, ...p } : t)));

  const onPick = (files: FileList | null) => {
    if (!files?.length) return;
    const next: FileTask[] = Array.from(files).map((f) => ({
      file: f,
      name: f.name,
      status: "pending",
    }));
    setTasks((prev) => [...prev, ...next]);
  };

  const makeClient = async (): Promise<IbdApiClient> => {
    const uid =
      localStorage.getItem("ibd_web_uid") ??
      (() => {
        const u = `web-${Date.now().toString(16)}`;
        localStorage.setItem("ibd_web_uid", u);
        return u;
      })();
    const api = createClient({
      baseUrl: import.meta.env.VITE_IBD_API_BASE ?? "",
      appUserId: uid,
    });
    const session = await api.parseSession();
    api.setToken(session.accessToken);
    return api;
  };

  const runBatch = async () => {
    setBusy(true);
    setMsg(null);
    let api: IbdApiClient;
    try {
      api = await makeClient();
    } catch (e) {
      setMsg(`解析会话失败（需先启动 API）：${e}`);
      setBusy(false);
      return;
    }

    for (const t of tasks) {
      if (t.status !== "pending") continue;
      patch(t.name, { status: "uploading", error: undefined });
      try {
        const bytes = new Uint8Array(await t.file.arrayBuffer());
        const presign = await api.presign({
          filename: t.name,
          contentType: t.file.type || "application/pdf",
        });
        await api.uploadBytes(presign, bytes);
        patch(t.name, { status: "parsing" });
        const job = await api.enqueueParse({
          objectKey: presign.objectKey,
          hospitalHint: hospital || undefined,
          reportType: reportType || undefined,
        });
        patch(t.name, { jobId: job.id });
        const done = await api.waitParseJob(job.id);
        if (done.status === "failed") {
          patch(t.name, { status: "failed", error: done.error ?? "解析失败" });
          continue;
        }
        const items = (done.items as LabItemDto[] | null) ?? [];
        try {
          await api.confirmParse(job.id, {
            items: items.map((i) => ({
              nameNorm: i.nameNorm,
              nameRaw: i.nameRaw,
              value: i.value,
              unit: i.unit,
              refMin: i.refMin,
              refMax: i.refMax,
              flag: i.flag ?? null,
            })),
            deleteSource: true,
          });
        } catch {
          await api.deleteParseSource(job.id).catch(() => undefined);
        }
        patch(t.name, { status: "done", items });
      } catch (e) {
        patch(t.name, { status: "failed", error: String(e) });
      }
    }
    setMsg("批量解析完成 · 云端原件默认用完即删");
    setBusy(false);
  };

  const confirmAll = async () => {
    setMsg("已逐份 confirm 写回（见各文件结果）");
  };

  return (
    <div>
      <h1>批量 PDF 解析</h1>
      <p className="hint">
        多文件上传 → 逐份解析 → 确认写回。默认「用完即删」云端原件。
      </p>
      <div className="card">
        <div className="row">
          <label>
            医院{" "}
            <input
              value={hospital}
              onChange={(e) => setHospital(e.target.value)}
              placeholder="如 三甲医院A"
            />
          </label>
          <label>
            报告类型{" "}
            <select
              value={reportType}
              onChange={(e) => setReportType(e.target.value)}
            >
              <option>血常规</option>
              <option>生化</option>
              <option>炎症指标</option>
            </select>
          </label>
          <input
            ref={fileInput}
            type="file"
            multiple
            accept=".pdf,.png,.jpg,.txt"
            onChange={(e) => onPick(e.target.files)}
          />
          <button disabled={busy || tasks.length === 0} onClick={runBatch}>
            {busy ? "处理中…" : "开始批量解析"}
          </button>
          <button className="ghost" onClick={confirmAll}>
            说明
          </button>
        </div>
        {msg && <div className="msg">{msg}</div>}
      </div>
      <div className="card">
        <table>
          <thead>
            <tr>
              <th>文件</th>
              <th>状态</th>
              <th>结果</th>
            </tr>
          </thead>
          <tbody>
            {tasks.map((t) => (
              <tr key={t.name}>
                <td>{t.name}</td>
                <td>{t.status}</td>
                <td>
                  {t.error ??
                    (t.items?.length
                      ? `${t.items.length} 项 · ${t.items
                          .slice(0, 3)
                          .map((i) => i.nameNorm)
                          .join("、")}`
                      : t.status === "done"
                        ? "已解析并写回"
                        : "—")}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
