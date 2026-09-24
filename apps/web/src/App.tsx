import { NavLink, Route, Routes } from "react-router-dom";
import ParseBatch from "./pages/ParseBatch";
import Trends from "./pages/Trends";
import ClinicalEdit from "./pages/ClinicalEdit";
import DataExport from "./pages/DataExport";

const tabs = [
  { to: "/", label: "趋势分析" },
  { to: "/parse", label: "批量解析" },
  { to: "/clinical", label: "检查/手术" },
  { to: "/export", label: "数据导出" },
];

export default function App() {
  return (
    <div className="shell">
      <header className="top">
        <div className="brand">
          <span className="logo">IBDers</span>
          <span className="sub">PC Web · 深度分析</span>
        </div>
        <nav className="nav">
          {tabs.map((t) => (
            <NavLink
              key={t.to}
              to={t.to}
              end={t.to === "/"}
              className={({ isActive }) => (isActive ? "tab on" : "tab")}
            >
              {t.label}
            </NavLink>
          ))}
          <a
            className="tab"
            href="/lab-panels.html"
            target="_blank"
            rel="noreferrer"
          >
            检验套餐模板
          </a>
        </nav>
      </header>
      <main className="main">
        <Routes>
          <Route path="/" element={<Trends />} />
          <Route path="/parse" element={<ParseBatch />} />
          <Route path="/clinical" element={<ClinicalEdit />} />
          <Route path="/export" element={<DataExport />} />
        </Routes>
      </main>
    </div>
  );
}
