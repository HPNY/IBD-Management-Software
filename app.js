/**
 * IBDers · 检验套餐模板维护
 * 数据结构对齐 apps/mobile/lib/core/lab/lab_panels.dart 与 CORE_LAB_NAMES。
 */

const CORE_LAB_NAMES = [
  "超敏C反应蛋白",
  "血沉",
  "粪便钙卫蛋白",
  "淋巴细胞",
  "白蛋白",
  "血红蛋白",
  "尿酸",
];

const STORAGE_KEY = "ibders.lab_panels.v1";

const DEFAULT_PANELS = [
  {
    id: "ibd_core",
    title: "IBD 核心",
    subtitle: "炎症 · 贫血 · 营养",
    items: [
      { nameNorm: "超敏C反应蛋白", nameRaw: "hs-CRP", unit: "mg/L", refMin: null, refMax: 5.0, sort: 1 },
      { nameNorm: "血沉", nameRaw: "ESR", unit: "mm/h", refMin: null, refMax: 15, sort: 2 },
      { nameNorm: "粪便钙卫蛋白", nameRaw: "FC", unit: "μg/g", refMin: null, refMax: 200, sort: 3 },
      { nameNorm: "淋巴细胞", nameRaw: "LYM", unit: "10^9/L", refMin: 1.1, refMax: 3.2, sort: 4 },
      { nameNorm: "白蛋白", nameRaw: "ALB", unit: "g/L", refMin: 40, refMax: 55, sort: 5 },
      { nameNorm: "血红蛋白", nameRaw: "Hb", unit: "g/L", refMin: 130, refMax: 175, sort: 6 },
      { nameNorm: "尿酸", nameRaw: "UA", unit: "μmol/L", refMin: 208, refMax: 428, sort: 7 },
    ],
  },
  {
    id: "cbc",
    title: "血常规",
    subtitle: "五分类常用项",
    items: [
      { nameNorm: "白细胞计数", nameRaw: "WBC", unit: "10^9/L", refMin: 3.5, refMax: 9.5, sort: 1 },
      { nameNorm: "中性粒细胞", nameRaw: "NEUT", unit: "10^9/L", refMin: 1.8, refMax: 6.3, sort: 2 },
      { nameNorm: "淋巴细胞", nameRaw: "LYM", unit: "10^9/L", refMin: 1.1, refMax: 3.2, sort: 3 },
      { nameNorm: "血红蛋白", nameRaw: "Hb", unit: "g/L", refMin: 130, refMax: 175, sort: 4 },
      { nameNorm: "血小板计数", nameRaw: "PLT", unit: "10^9/L", refMin: 125, refMax: 350, sort: 5 },
      { nameNorm: "红细胞压积", nameRaw: "HCT", unit: "%", refMin: 40, refMax: 50, sort: 6 },
    ],
  },
  {
    id: "inflammation",
    title: "炎症指标",
    subtitle: "CRP / 血沉 / 钙卫蛋白",
    items: [
      { nameNorm: "超敏C反应蛋白", nameRaw: "hs-CRP", unit: "mg/L", refMin: null, refMax: 5.0, sort: 1 },
      { nameNorm: "C反应蛋白", nameRaw: "CRP", unit: "mg/L", refMin: null, refMax: 8.0, sort: 2 },
      { nameNorm: "血沉", nameRaw: "ESR", unit: "mm/h", refMin: null, refMax: 15, sort: 3 },
      { nameNorm: "粪便钙卫蛋白", nameRaw: "FC", unit: "μg/g", refMin: null, refMax: 200, sort: 4 },
      { nameNorm: "降钙素原", nameRaw: "PCT", unit: "ng/mL", refMin: null, refMax: 0.05, sort: 5 },
    ],
  },
  {
    id: "liver",
    title: "肝功能",
    subtitle: "转氨酶 · 胆红素 · 蛋白",
    items: [
      { nameNorm: "丙氨酸氨基转移酶", nameRaw: "ALT", unit: "U/L", refMin: null, refMax: 40, sort: 1 },
      { nameNorm: "天门冬氨酸氨基转移酶", nameRaw: "AST", unit: "U/L", refMin: null, refMax: 40, sort: 2 },
      { nameNorm: "白蛋白", nameRaw: "ALB", unit: "g/L", refMin: 40, refMax: 55, sort: 3 },
      { nameNorm: "总胆红素", nameRaw: "TBIL", unit: "μmol/L", refMin: 3.4, refMax: 20.5, sort: 4 },
      { nameNorm: "直接胆红素", nameRaw: "DBIL", unit: "μmol/L", refMin: null, refMax: 6.8, sort: 5 },
      { nameNorm: "γ-谷氨酰转肽酶", nameRaw: "GGT", unit: "U/L", refMin: null, refMax: 50, sort: 6 },
      { nameNorm: "碱性磷酸酶", nameRaw: "ALP", unit: "U/L", refMin: 45, refMax: 125, sort: 7 },
    ],
  },
  {
    id: "kidney_metabolic",
    title: "肾功能代谢",
    subtitle: "尿酸 · 肌酐 · 电解质",
    items: [
      { nameNorm: "尿酸", nameRaw: "UA", unit: "μmol/L", refMin: 208, refMax: 428, sort: 1 },
      { nameNorm: "肌酐", nameRaw: "Cr", unit: "μmol/L", refMin: 41, refMax: 81, sort: 2 },
      { nameNorm: "尿素氮", nameRaw: "BUN", unit: "mmol/L", refMin: 2.9, refMax: 8.2, sort: 3 },
      { nameNorm: "估算肾小球滤过率", nameRaw: "eGFR", unit: "mL/min", refMin: 90, refMax: null, sort: 4 },
      { nameNorm: "钾", nameRaw: "K", unit: "mmol/L", refMin: 3.5, refMax: 5.3, sort: 5 },
      { nameNorm: "钠", nameRaw: "Na", unit: "mmol/L", refMin: 137, refMax: 147, sort: 6 },
      { nameNorm: "钙", nameRaw: "Ca", unit: "mmol/L", refMin: 2.11, refMax: 2.52, sort: 7 },
    ],
  },
  {
    id: "nutrition_anemia",
    title: "营养贫血",
    subtitle: "铁代谢 · 维生素",
    items: [
      { nameNorm: "血红蛋白", nameRaw: "Hb", unit: "g/L", refMin: 130, refMax: 175, sort: 1 },
      { nameNorm: "血清铁蛋白", nameRaw: "Ferritin", unit: "μg/L", refMin: 30, refMax: 400, sort: 2 },
      { nameNorm: "维生素B12", nameRaw: "VB12", unit: "pmol/L", refMin: 145, refMax: 569, sort: 3 },
      { nameNorm: "叶酸", nameRaw: "Folate", unit: "nmol/L", refMin: 7.0, refMax: 46.4, sort: 4 },
      { nameNorm: "白蛋白", nameRaw: "ALB", unit: "g/L", refMin: 40, refMax: 55, sort: 5 },
      { nameNorm: "前白蛋白", nameRaw: "PA", unit: "mg/L", refMin: 200, refMax: 400, sort: 6 },
    ],
  },
];

/** @type {{panels: Array}} */
let state = { panels: [] };
let activePanelId = null;
let editingItemIndex = null;
let dirty = false;

function deepClone(v) {
  return JSON.parse(JSON.stringify(v));
}

function load() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      if (parsed && Array.isArray(parsed.panels)) {
        state.panels = normalizePanels(parsed.panels);
        if (!state.panels.length) throw new Error("empty");
        activePanelId = state.panels[0].id;
        return;
      }
    }
  } catch (_) {
    /* fall through to defaults */
  }
  state.panels = deepClone(DEFAULT_PANELS);
  activePanelId = state.panels[0].id;
}

function save() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify({ version: 1, panels: state.panels }));
  dirty = false;
}

function normalizePanels(panels) {
  return panels.map((p, pi) => ({
    id: String(p.id || `panel_${Date.now()}_${pi}`),
    title: String(p.title || "未命名套餐"),
    subtitle: p.subtitle != null ? String(p.subtitle) : "",
    items: (Array.isArray(p.items) ? p.items : []).map((it, ii) => normalizeItem(it, ii)),
  }));
}

function normalizeItem(it, ii) {
  const num = (v) => {
    if (v == null || v === "") return null;
    const n = Number(v);
    return Number.isFinite(n) ? n : null;
  };
  return {
    nameNorm: String(it.nameNorm || it.name_norm || "").trim() || "未命名",
    nameRaw: it.nameRaw != null || it.name_raw != null ? String(it.nameRaw ?? it.name_raw ?? "") : "",
    unit: String(it.unit || ""),
    refMin: num(it.refMin ?? it.ref_min),
    refMax: num(it.refMax ?? it.ref_max),
    sort: Number.isFinite(Number(it.sort)) ? Number(it.sort) : ii + 1,
  };
}

function activePanel() {
  return state.panels.find((p) => p.id === activePanelId) || null;
}

function uid(prefix) {
  return `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 7)}`;
}

function toast(msg) {
  const el = document.getElementById("toast");
  el.textContent = msg;
  el.classList.add("show");
  clearTimeout(toast._t);
  toast._t = setTimeout(() => el.classList.remove("show"), 1800);
}

function fmtRef(item) {
  const { refMin: min, refMax: max } = item;
  if (min != null && max != null) return `${min}–${max}`;
  if (max != null) return `<${max}`;
  if (min != null) return `>${min}`;
  return "—";
}

function renderPanelList() {
  const root = document.getElementById("panel-list");
  root.innerHTML = "";
  if (!state.panels.length) {
    root.innerHTML = `<div class="empty">暂无套餐，点右上角「新建套餐」</div>`;
    return;
  }
  state.panels.forEach((p) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = `panel-item${p.id === activePanelId ? " active" : ""}`;
    btn.innerHTML = `
      <div class="title"></div>
      <div class="meta"></div>
    `;
    btn.querySelector(".title").textContent = p.title;
    btn.querySelector(".meta").textContent =
      `${p.items.length} 项${p.subtitle ? " · " + p.subtitle : ""}`;
    btn.addEventListener("click", () => {
      activePanelId = p.id;
      editingItemIndex = null;
      renderAll();
    });
    root.appendChild(btn);
  });
}

function renderMain() {
  const panel = activePanel();
  const headTitle = document.getElementById("active-title");
  const body = document.getElementById("main-body");
  if (!panel) {
    headTitle.textContent = "未选择套餐";
    body.innerHTML = `<div class="empty">从左侧选择或新建一个检验套餐</div>`;
    return;
  }
  headTitle.textContent = panel.title;

  body.innerHTML = `
    <p class="hint">
      小项 <code>nameNorm</code> 使用中文规范名（对接趋势 / 发作预警，见
      <code>packages/domain-types</code> CORE_LAB_NAMES）。保存后可导出 JSON 供 App 手动录入模板对齐。
    </p>
    <div class="form-grid" id="panel-meta">
      <div class="field span2">
        <label for="p-title">套餐名称（大项）</label>
        <input id="p-title" value="" />
      </div>
      <div class="field span2">
        <label for="p-subtitle">副标题</label>
        <input id="p-subtitle" value="" />
      </div>
      <div class="field span2">
        <label for="p-id">ID（稳定标识）</label>
        <input id="p-id" value="" />
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>规范名 nameNorm</th>
            <th>原始名 nameRaw</th>
            <th>单位</th>
            <th>参考下限</th>
            <th>参考上限</th>
            <th>操作</th>
          </tr>
        </thead>
        <tbody id="item-rows"></tbody>
      </table>
    </div>
    <div id="item-editor"></div>
  `;

  const title = document.getElementById("p-title");
  const subtitle = document.getElementById("p-subtitle");
  const idInput = document.getElementById("p-id");
  title.value = panel.title;
  subtitle.value = panel.subtitle || "";
  idInput.value = panel.id;

  title.addEventListener("input", () => {
    panel.title = title.value;
    dirty = true;
    renderPanelList();
  });
  subtitle.addEventListener("input", () => {
    panel.subtitle = subtitle.value;
    dirty = true;
    renderPanelList();
  });
  idInput.addEventListener("change", () => {
    const next = idInput.value.trim() || panel.id;
    const clash = state.panels.some((p) => p !== panel && p.id === next);
    if (clash) {
      toast("ID 已存在");
      idInput.value = panel.id;
      return;
    }
    const old = panel.id;
    panel.id = next;
    if (activePanelId === old) activePanelId = next;
    dirty = true;
    renderPanelList();
  });

  renderRows(panel);
  renderItemEditor(panel);
}

function renderRows(panel) {
  const tbody = document.getElementById("item-rows");
  tbody.innerHTML = "";
  const items = [...panel.items].sort((a, b) => a.sort - b.sort);
  if (!items.length) {
    tbody.innerHTML = `<tr><td colspan="7" class="empty">尚无小项，点「添加小项」</td></tr>`;
    return;
  }
  items.forEach((item, sortedIdx) => {
    const realIndex = panel.items.indexOf(item);
    const isCore = CORE_LAB_NAMES.includes(item.nameNorm);
    const tr = document.createElement("tr");
    if (isCore) tr.classList.add("core");
    tr.innerHTML = `
      <td>${sortedIdx + 1}</td>
      <td class="name-norm"></td>
      <td class="name-raw"></td>
      <td class="unit"></td>
      <td class="rmin"></td>
      <td class="rmax"></td>
      <td class="row-actions">
        <button type="button" class="icon-btn" data-act="edit">编辑</button>
        <button type="button" class="icon-btn" data-act="up">上移</button>
        <button type="button" class="icon-btn" data-act="down">下移</button>
        <button type="button" class="icon-btn danger" data-act="del">删除</button>
      </td>
    `;
    const nameCell = tr.querySelector(".name-norm");
    nameCell.textContent = item.nameNorm;
    if (isCore) {
      const tag = document.createElement("span");
      tag.className = "core-tag";
      tag.textContent = "核心";
      nameCell.appendChild(tag);
    }
    tr.querySelector(".name-raw").textContent = item.nameRaw || "—";
    tr.querySelector(".unit").textContent = item.unit || "—";
    tr.querySelector(".rmin").textContent = item.refMin != null ? item.refMin : "—";
    tr.querySelector(".rmax").textContent = item.refMax != null ? item.refMax : "—";

    tr.querySelector('[data-act="edit"]').addEventListener("click", () => {
      editingItemIndex = realIndex;
      renderItemEditor(panel);
    });
    tr.querySelector('[data-act="del"]').addEventListener("click", () => {
      if (!confirm(`删除小项「${item.nameNorm}」？`)) return;
      panel.items.splice(realIndex, 1);
      if (editingItemIndex === realIndex) editingItemIndex = null;
      dirty = true;
      renderAll();
      toast("已删除小项");
    });
    tr.querySelector('[data-act="up"]').addEventListener("click", () => moveItem(panel, item, -1));
    tr.querySelector('[data-act="down"]').addEventListener("click", () => moveItem(panel, item, 1));

    tbody.appendChild(tr);
  });
}

function moveItem(panel, item, dir) {
  const sorted = [...panel.items].sort((a, b) => a.sort - b.sort);
  const i = sorted.indexOf(item);
  const j = i + dir;
  if (j < 0 || j >= sorted.length) return;
  const a = sorted[i];
  const b = sorted[j];
  const t = a.sort;
  a.sort = b.sort;
  b.sort = t;
  dirty = true;
  renderRows(panel);
}

function renderItemEditor(panel) {
  const root = document.getElementById("item-editor");
  const isNew = editingItemIndex == null;
  const item = isNew
    ? { nameNorm: "", nameRaw: "", unit: "", refMin: null, refMax: null, sort: panel.items.length + 1 }
    : panel.items[editingItemIndex];
  if (!item) {
    root.innerHTML = "";
    return;
  }

  root.innerHTML = `
    <div class="item-editor">
      <h3>${isNew ? "添加小项" : "编辑小项"}</h3>
      <div class="form-grid">
        <div class="field span2">
          <label for="i-norm">规范名 nameNorm *</label>
          <input id="i-norm" list="core-names" value="" />
          <datalist id="core-names"></datalist>
        </div>
        <div class="field">
          <label for="i-raw">原始名 nameRaw</label>
          <input id="i-raw" value="" />
        </div>
        <div class="field">
          <label for="i-unit">单位 unit *</label>
          <input id="i-unit" value="" />
        </div>
        <div class="field">
          <label for="i-min">参考下限 refMin</label>
          <input id="i-min" type="number" step="any" value="" />
        </div>
        <div class="field">
          <label for="i-max">参考上限 refMax</label>
          <input id="i-max" type="number" step="any" value="" />
        </div>
        <div class="field">
          <label for="i-sort">排序 sort</label>
          <input id="i-sort" type="number" step="1" value="" />
        </div>
      </div>
      <div class="item-actions">
        <button type="button" class="btn primary" id="i-save">${isNew ? "添加" : "保存修改"}</button>
        <button type="button" class="btn" id="i-cancel">${isNew ? "清空" : "取消"}</button>
      </div>
    </div>
  `;

  const dl = document.getElementById("core-names");
  CORE_LAB_NAMES.forEach((n) => {
    const opt = document.createElement("option");
    opt.value = n;
    dl.appendChild(opt);
  });

  const norm = document.getElementById("i-norm");
  const raw = document.getElementById("i-raw");
  const unit = document.getElementById("i-unit");
  const min = document.getElementById("i-min");
  const max = document.getElementById("i-max");
  const sort = document.getElementById("i-sort");
  norm.value = item.nameNorm || "";
  raw.value = item.nameRaw || "";
  unit.value = item.unit || "";
  min.value = item.refMin != null ? item.refMin : "";
  max.value = item.refMax != null ? item.refMax : "";
  sort.value = item.sort != null ? item.sort : panel.items.length + 1;

  document.getElementById("i-cancel").addEventListener("click", () => {
    editingItemIndex = null;
    renderItemEditor(panel);
  });

  document.getElementById("i-save").addEventListener("click", () => {
    const nameNorm = norm.value.trim();
    const unitVal = unit.value.trim();
    if (!nameNorm || !unitVal) {
      toast("规范名与单位必填");
      return;
    }
    const next = normalizeItem(
      {
        nameNorm,
        nameRaw: raw.value.trim(),
        unit: unitVal,
        refMin: min.value === "" ? null : min.value,
        refMax: max.value === "" ? null : max.value,
        sort: sort.value,
      },
      panel.items.length,
    );

    if (isNew) {
      // 同一大项内 nameNorm 不重复（与 mergeLabItems 语义一致）
      if (panel.items.some((it) => it.nameNorm === next.nameNorm)) {
        toast("该套餐内已有同名规范名");
        return;
      }
      panel.items.push(next);
      toast("已添加小项");
    } else {
      const clash = panel.items.some(
        (it, idx) => idx !== editingItemIndex && it.nameNorm === next.nameNorm,
      );
      if (clash) {
        toast("该套餐内已有同名规范名");
        return;
      }
      panel.items[editingItemIndex] = next;
      toast("已保存小项");
    }
    dirty = true;
    editingItemIndex = null;
    renderAll();
  });
}

function renderAll() {
  renderPanelList();
  renderMain();
}

function addPanel() {
  const id = uid("panel");
  state.panels.push({
    id,
    title: `新套餐 ${state.panels.length + 1}`,
    subtitle: "",
    items: [],
  });
  activePanelId = id;
  editingItemIndex = null;
  dirty = true;
  renderAll();
  toast("已新建套餐");
}

function deletePanel() {
  const panel = activePanel();
  if (!panel) return;
  if (!confirm(`删除套餐「${panel.title}」及其全部小项？`)) return;
  state.panels = state.panels.filter((p) => p !== panel);
  activePanelId = state.panels[0]?.id || null;
  editingItemIndex = null;
  dirty = true;
  renderAll();
  toast("已删除套餐");
}

function duplicatePanel() {
  const panel = activePanel();
  if (!panel) return;
  const copy = deepClone(panel);
  copy.id = uid("panel");
  copy.title = `${panel.title} 副本`;
  state.panels.push(copy);
  activePanelId = copy.id;
  editingItemIndex = null;
  dirty = true;
  renderAll();
  toast("已复制套餐");
}

function exportJson() {
  const payload = {
    version: 1,
    exportedAt: new Date().toISOString(),
    coreLabNames: CORE_LAB_NAMES,
    panels: state.panels,
  };
  const blob = new Blob([JSON.stringify(payload, null, 2)], {
    type: "application/json;charset=utf-8",
  });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `ibders-lab-panels-${new Date().toISOString().slice(0, 10)}.json`;
  a.click();
  URL.revokeObjectURL(a.href);
  toast("已导出 JSON");
}

function exportDart() {
  // 生成可贴回 lab_panels.dart 的片段（便于与 App 内置模板对齐）
  const lines = ["const List<LabPanel> kLabPanels = ["];
  state.panels.forEach((p) => {
    lines.push("  LabPanel(");
    lines.push(`    id: '${p.id}',`);
    lines.push(`    title: '${p.title}',`);
    if (p.subtitle) lines.push(`    subtitle: '${p.subtitle}',`);
    lines.push("    items: [");
    [...p.items]
      .sort((a, b) => a.sort - b.sort)
      .forEach((it) => {
        const parts = [`nameNorm: '${it.nameNorm}'`];
        if (it.nameRaw) parts.push(`nameRaw: '${it.nameRaw}'`);
        parts.push(`unit: '${it.unit}'`);
        if (it.refMin != null) parts.push(`refMin: ${it.refMin}`);
        if (it.refMax != null) parts.push(`refMax: ${it.refMax}`);
        lines.push(`      LabItemSpec(${parts.join(", ")}),`);
      });
    lines.push("    ],");
    lines.push("  ),");
  });
  lines.push("];");
  const blob = new Blob([lines.join("\n")], { type: "text/plain;charset=utf-8" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "lab_panels_snippet.dart";
  a.click();
  URL.revokeObjectURL(a.href);
  toast("已导出 Dart 片段");
}

function importJsonFile(file) {
  const reader = new FileReader();
  reader.onload = () => {
    try {
      const parsed = JSON.parse(String(reader.result));
      const panels = normalizePanels(parsed.panels || parsed);
      if (!panels.length) throw new Error("文件中没有套餐");
      if (!confirm(`导入 ${panels.length} 个套餐并替换当前数据？`)) return;
      state.panels = panels;
      activePanelId = panels[0].id;
      editingItemIndex = null;
      dirty = true;
      save();
      renderAll();
      toast("导入成功");
    } catch (e) {
      toast(`导入失败：${e.message || e}`);
    }
  };
  reader.readAsText(file, "utf-8");
}

function resetDefaults() {
  if (!confirm("重置为内置默认模板？当前修改将丢失。")) return;
  state.panels = deepClone(DEFAULT_PANELS);
  activePanelId = state.panels[0].id;
  editingItemIndex = null;
  save();
  renderAll();
  toast("已重置默认模板");
}

function bindChrome() {
  document.getElementById("btn-new").addEventListener("click", addPanel);
  document.getElementById("btn-dup").addEventListener("click", duplicatePanel);
  document.getElementById("btn-del").addEventListener("click", deletePanel);
  document.getElementById("btn-save").addEventListener("click", () => {
    save();
    toast("已保存到浏览器本地存储");
  });
  document.getElementById("btn-export").addEventListener("click", exportJson);
  document.getElementById("btn-export-dart").addEventListener("click", exportDart);
  document.getElementById("btn-reset").addEventListener("click", resetDefaults);
  document.getElementById("file-import").addEventListener("change", (e) => {
    const file = e.target.files?.[0];
    if (file) importJsonFile(file);
    e.target.value = "";
  });
  window.addEventListener("beforeunload", (e) => {
    if (dirty) {
      e.preventDefault();
      e.returnValue = "";
    }
  });
}

document.addEventListener("DOMContentLoaded", () => {
  load();
  bindChrome();
  renderAll();
});
