import { defineConfig, type UserConfigExport } from "@tarojs/cli";

export default defineConfig(async (merge) => {
  const base: UserConfigExport = {
    projectName: "ibd-miniapp",
    date: "2026-9-22",
    designWidth: 750,
    deviceRatio: {
      640: 2.34 / 2,
      750: 1,
      375: 2,
      828: 1.81 / 2,
    },
    sourceRoot: "src",
    outputRoot: "dist",
    plugins: [],
    defineConstants: {},
    copy: { patterns: [], options: {} },
    framework: "react",
    compiler: "webpack5",
    cache: { enable: false },
    mini: {
      postcss: {
        pxtransform: { enable: true, config: {} },
        cssModules: { enable: false },
      },
    },
  };
  return merge({}, base, {});
});
