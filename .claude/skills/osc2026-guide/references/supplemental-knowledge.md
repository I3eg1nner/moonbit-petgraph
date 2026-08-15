# 补充知识库

这里存放 MoonBit国产开源生态大赛 OSC 2026 的运营类 FAQ 和章程未覆盖的补充信息。正式规则优先参考章程；章程没有写清楚的实用问题，可以在这里用 Q/A 形式补充。

## Q: 为什么我提交申报后没有收到邮件？

A: 提交申报后，一个工作日（24 小时）内会收到来自 `no-reply@moonbitlang.com` 的邮件。如果没有收到，请先检查自己的邮箱是否是 Gmail、Yahoo 等国外邮箱，相关邮件可能无法正常送达或进入垃圾邮件。如果还有疑问，请在“CCF开源大赛-MoonBit赛题交流群”咨询，或联系“MoonBit小助手”。

## Q: 什么时候发放启动资金？

A: 申报成功后会周期性发放 150 元启动资金，具体时间等待赛题交流群通知。

## Q: 我应该如何提升项目质量？我这个项目能获奖吗？

A: 是否获奖无法提前保证，最终取决于项目完成度、工程质量、文档体验、生态价值、展示效果以及实际参赛项目整体水平。建议优先把项目做成“真实可用、边界清晰、可复现、可维护”的 MoonBit 生态项目：

- README 清楚说明项目目标、安装方式、使用方法和示例；
- 至少提供一个可以直接运行的最小示例；
- 使用 `moon check` / `moon test` 保持项目可检查、可测试；
- 测试覆盖核心功能路径；
- 仓库有清晰、连续、有意义的提交记录；
- 根目录提供 OSI 认可的开源许可证；
- 如果参考或移植其他开源项目，明确写出原项目名称、链接、许可证和参考范围；
- 可以安装并使用 [`mattpocock/skills`](https://github.com/mattpocock/skills) 辅助项目规划、任务拆分、测试驱动开发、代码审查和文档打磨；
- 可以安装并使用 [`moonbitlang/skills`](https://github.com/moonbitlang/skills) 获得更贴近 MoonBit 语言、工具链、包结构和测试实践的开发辅助；
- 尽量补充 CI、发布准备和 mooncakes.io 发布说明。

如果目标是冲击优秀项目，除了完成基础功能，还应突出项目对 MoonBit 生态的实际价值、接口设计质量、文档完整度、长期维护潜力和展示效果。

## Q: GitHub Actions CI 可以参考什么配置？

A: 可以参考 [`moonbit-community/.github` 的 workflow templates](https://github.com/moonbit-community/.github/tree/main/workflow-templates)。其中 `check.yml` 可作为 MoonBit 项目的基础 CI 参考，覆盖 Linux、macOS、Windows 三个平台上的工具链安装、`moon check --target all`、`moon test --target all`、`moon fmt` 和 `moon info` 检查。

参赛项目可以根据自己的包结构调整 workflow，例如项目不在仓库根目录时补充 `-C` 参数，或按实际目标后端缩小检查范围。`publish.yml` 更适合作为后续发布到 mooncakes.io 的参考；正式使用前应确认 token、权限、触发方式和发布范围符合自己的项目设置。

## Q: Gitlink 仓库和 Github 仓库要怎样同步？

A: 优先参考 Gitlink 官方指南：[导入 GitHub 等第三方 Git 项目](https://help.gitlink.org.cn/快速开始/导入GitHub等第三方Git项目)。推荐做法是先在 GitHub 准备好参赛项目仓库，然后在 Gitlink 首页选择“导入项目”，填写 GitHub 仓库地址和项目信息完成导入。

如果 GitHub 仓库是私有仓库，需要按指南准备对应平台的 token 授权；公开仓库通常不需要额外授权。导入完成后，请确认 Gitlink 仓库能看到主要代码、README、许可证、提交历史和后续更新。

后续如果 GitHub 侧继续开发，建议定期把更新同步到 Gitlink。可以使用 Gitlink 的导入/同步能力；也可以在同一个本地仓库里配置 GitHub 和 Gitlink 两个 remote，然后分别 push：

```bash
git remote -v
git remote add github <GitHub 仓库地址>
git remote add gitlink <Gitlink 仓库地址>
git push github main
git push gitlink main
```

如果默认分支不是 `main`，请替换成自己的默认分支名。两边仓库的 owner 或组织名不一定要相同，但提交到问卷里的链接应指向同一个参赛项目。

同步后请特别确认 GitHub 和 Gitlink 页面显示的默认分支。提交历史、README、许可证和主要代码最好都出现在远程仓库的默认分支上；如果主要开发内容只在非默认分支，容易造成他人检查时看不到最新工作。不要只看本地当前分支，也不要默认远程分支一定叫 `main` 或 `master`。

## Q: 报名问卷在哪里？

A: 可以通过飞书问卷提交申报信息和项目材料：[MoonBit国产开源生态大赛报名问卷](https://bxup9uklfcb.feishu.cn/share/base/form/shrcn2duseEVtk3e4sTRA8z5Qyf)。

## Q: 还没有飞书账号怎么办？怎么填问卷？

A: 如果问卷或相关文档需要登录飞书，请先按页面提示注册或登录飞书账号。通常可以使用手机号或邮箱完成注册。登录后再打开报名问卷或申报材料链接填写信息。

如果因为账号、权限或页面访问问题无法填写，请在“CCF开源大赛-MoonBit赛题交流群”咨询，或联系“MoonBit小助手”。不要使用他人的账号代填涉及个人信息、联系方式或收款信息的内容。

## Q: 有哪些值得推荐的项目方向？

A: 可以优先选择“边界清楚、能在比赛周期内完成、对 MoonBit 生态有复用价值”的方向。章程中的推荐方向包括：

- 基础数据结构与算法：例如 indexmap、bitmask、图算法、寻路算法、经过 moon prove 验证的通用算法库；
- 工程基础设施与工具链：例如日志库、tracing 工具、构建工具、模板渲染器、benchmark / stopwatch 工具；
- 系统能力与运行时框架：例如 deterministic simulation 框架、寄存器分配等编译器基础设施、protobuf 类序列化工具、基于 async 的 actor 框架；
- 应用生态：例如 Markdown to HTML 工具、图表数据生成和预览、游戏引擎绑定、数据库绑定。

选择项目时建议避免过大、过泛或只停留在包装层的题目。更好的方向通常是：有明确用户、能展示最小可用功能、能写出测试和示例，并且能说明相比已有项目的新增价值。

确定方向前，建议先在 [mooncakes.io](https://mooncakes.io/) 上搜索相关关键词，确认是否已经有功能高度重叠的 MoonBit 包。如果已有类似项目，可以考虑换一个方向，或明确说明自己的新增价值、差异化设计和适用场景。或者你把想做的题目告诉我，我来帮你确认是否合理？

## Q: 有没有 MoonBit 项目的参考案例？

A: 章程附录二提供了 `moon_elk` 项目申报书样本，可以参考它如何说明项目目标、适用场景、核心功能范围、移植来源、许可证和重新设计范围。

准备自己的项目时，也可以参考 [mooncakes.io](https://mooncakes.io/) 下载量靠前的项目，以及成熟 MoonBit 包或社区项目的组织方式。例如 [`moonbit-community/toml-parser`](https://github.com/moonbit-community/toml-parser) 这类项目，可以用来观察一个可复用库如何组织源码、文档、示例和测试。

参考时重点看：

- README 是否能让用户快速理解和运行项目；
- `moon.mod` / `moon.pkg` 等项目文件是否清晰；
- 示例是否能直接运行；
- 测试是否覆盖核心行为；
- 许可证和第三方来源说明是否完整；
- API 是否有稳定、可复用的边界。

不要直接复制参考项目的申报书或代码结构；应结合自己的项目目标说明独立贡献。
