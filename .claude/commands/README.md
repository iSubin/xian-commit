# Claude Commands

本目录保存 Claude Code 命令模板。

## 命令分组

通用治理命令：

- `/xian-next`
- `/xian-spec`
- `/xian-design`
- `/xian-plan`
- `/xian-build`
- `/xian-verify`
- `/xian-review`
- `/xian-gate`
- `/xian-workbench`
- `/xian-archive`

RuoYi 垂直命令：

- `/ruoyi-crud`
- `/ruoyi-check`
- `/ruoyi-deploy`
- `/ruoyi-sync`
- `/ruoyi-strip`

## 原则

Command 是用户高频动作入口。命令内部应加载对应 Skill，并调用协议和工具完成确定性动作。
