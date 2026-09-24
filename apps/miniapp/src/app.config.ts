export default defineAppConfig({
  pages: [
    "pages/index/index",
    "pages/labs/index",
    "pages/checkin/index",
    "pages/injection/index",
    "pages/summary/index",
  ],
  window: {
    backgroundTextStyle: "dark",
    navigationBarBackgroundColor: "#0B6E4F",
    navigationBarTitleText: "IBDers",
    navigationBarTextStyle: "white",
    backgroundColor: "#F6F7F5",
  },
  tabBar: {
    color: "#6B7280",
    selectedColor: "#0B6E4F",
    backgroundColor: "#FFFFFF",
    list: [
      { pagePath: "pages/index/index", text: "首页" },
      { pagePath: "pages/labs/index", text: "检验" },
      { pagePath: "pages/checkin/index", text: "打卡" },
      { pagePath: "pages/injection/index", text: "注射" },
      { pagePath: "pages/summary/index", text: "摘要" },
    ],
  },
});
