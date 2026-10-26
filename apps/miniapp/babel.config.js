// Taro 3.6 标准 babel 配置（T0.5：修复缺失配置导致的构建失败——
// 此前 babel-loader 无 TS/TSX preset，解析 src/app.ts 直接报错）。
// babel-preset-taro 选项见：
// https://github.com/NervJS/taro/blob/next/packages/babel-preset-taro/README.md
module.exports = {
  presets: [
    ['taro', {
      framework: 'react',
      ts: true,
    }],
  ],
}
