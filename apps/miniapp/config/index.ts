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
      // T0.5：工作区包（packages/*）以 TS 源码被 @ibd/api-client 等引用，
      // Taro 默认 babel-loader 只覆盖应用 src，需为其补规则，否则 webpack
      // 直接解析 TS 语法（如 declare const）报 ModuleParseError。
      webpackChain(chain) {
        chain.module
          .rule("workspace-ts")
          .test(/\.(ts|tsx)$/)
          .include
          .add(/[/\\]packages[/\\]/)
          .end()
          .use("babel-loader")
          .loader("babel-loader")
          .options({
            presets: [["taro", { framework: "react", ts: true }]],
            cacheDirectory: true,
          });
      },
      postcss: {
        pxtransform: { enable: true, config: {} },
        cssModules: { enable: false },
      },
    },
  };
  return merge({}, base, {});
});
