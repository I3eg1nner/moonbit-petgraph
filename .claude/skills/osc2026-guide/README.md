# osc2026-guide

面向 MoonBit国产开源生态大赛 OSC 2026 选手的全流程 Agent skill。

## 安装

推荐使用 `skills` CLI 安装：

```bash
npx skills@latest add Milky2018/osc2026-guide -g --skill osc2026-guide --agent universal
```

也可以手动克隆到本地 Agent skill 目录：

```bash
mkdir -p ~/.agent/skills
git clone https://github.com/Milky2018/osc2026-guide.git ~/.agent/skills/osc2026-guide
```

如果 skill 列表没有自动刷新，请重启对应工具。

## 使用

在需要了解比赛信息或检查项目时调用：

```text
使用 $osc2026-guide 介绍一下 MoonBit国产开源生态大赛，我可以咨询哪些问题？
```

需要自查当前项目时可以说：

```text
使用 $osc2026-guide 检查当前仓库是否适合提交到 MoonBit国产开源生态大赛。
```
