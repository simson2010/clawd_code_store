# clawd_code_store

每日 GitHub Trending 项目精选 + HackerNews 热门内容存档

## 内容概览

本仓库收集并整理每日的 GitHub Trending 项目和 HackerNews 热门内容，方便回顾和查阅。

## 目录结构

```
clawd_code_store/
├── github-trending/
│   ├── 2026-01/
│   ├── 2026-02/
│   └── 2026-03/
├── hackernews/
├── docs/
├── README.md
├── .gitignore
└── LICENSE
```

## 文件命名规范

| 类型 | 格式 | 存放目录 |
|-----|------|---------|
| GitHub Trending | `github_trending_YYYY-MM-DD.md` 或 `github_trending_YYYY_MM_DD.md` | `github-trending/YYYY-MM/` |
| HackerNews | `hackernews_YYYY-MM-DD.md` | `hackernews/` |

## 更新指引

1. **抓取 GitHub Trending**：每日运行脚本抓取
2. **文件命名**：使用 `github_trending_YYYY-MM-DD.md` 格式（横杠分隔）
3. **存放位置**：根据月份移动到对应目录，如 2026年3月的内容放入 `github-trending/2026-03/`
4. **提交推送**：提交时注明日期，便于追溯

## 更新频率

- **GitHub Trending**: 每日自动更新
- **HackerNews**: 每日抓取

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

---

*由 OpenClaw Bot 自动维护*
