# 借光 · 版本控制与协作手册（人话版）

> 面向 4 人、零基础、约 10 周的课程项目。
> 目标就三件事：**谁改了什么大家都看得到；改坏了能退回上一个好版本；想从某个旧版本另起一条路继续做也能做。**
> 规则细节见 `README.md` 和 `docs/bible/`；本文是"照着做就行"的操作手册。

---

## 0. 先把这件事想明白

把做游戏当成写一篇文章，Git 就是"存档 + 历史记录"系统：

- 你每完成一小段，就**存一次档**（commit）；
- 每次存档都有记录：谁、什么时候、改了什么；
- 想回到某次存档，随时能回去；
- 云端（GitHub）存着所有人的存档，谁存了新的，别人**拉一下**就能拿到。

一句话：**Git = 存档系统；GitHub = 放存档的云盘。**

> 注意：GitHub 只是"放仓库的地方"，真正干版本控制活的是 Git。换平台不影响你怎么存档。

---

## 1. 名词对照表（先背这几个）

| 名词 | 人话解释 |
| --- | --- |
| 仓库 repository | 整个项目（含全部历史） |
| 本地仓库 | 你电脑上的那一份 |
| 远程仓库 | GitHub 上的那一份 |
| 提交 commit | 存一次档 |
| 推送 push | 把你的存档传到 GitHub |
| 拉取 pull | 把别人的新存档拉到自己电脑 |
| 分支 branch | 一条平行的时间线，互不干扰 |
| main | 主分支，**必须随时能玩** |
| 合并 merge | 把你那条线的改动并回主干 |
| PR（Pull Request） | "我做完了，请检查后并进来"的申请 |
| 冲突 conflict | 你和别人改了同一行，Git 不知道听谁的，要人来决定 |
| tag | 给某次存档起个名字，比如 `v0.1` |

---

## 2. 五条铁律（最重要，违反就出事）

1. **`main` 永远能跑起来。** 任何时候打开 `main`，按 F5 都得能进游戏。
2. **谁都不许直接改 `main`。** 只能通过 PR 合进去。
3. **开工前先拉，收工后推。** 早上 `pull`，干完 `push`。
4. **一次提交只做一件事。** 别把"改玩家移动 + 修门 + 换字体"混在一次里。
5. **动共享文件先打个招呼。** 见第 7 节清单。

---

## 3. 只有三种分支（不要更多）

| 分支 | 干什么 | 谁能提交 |
| --- | --- | --- |
| `main` | 稳定版，随时能玩 | 只通过 PR |
| `feat/xxx` | 做新功能，如 `feat/player-movement` | 做的人 |
| `fix/xxx` | 修 bug，如 `fix/door-collision` | 修的人 |

我们项目小，加更多分支只会让大家互相等，**不要加**。

---

## 4. 每天照着做（7 步）

```bash
# ① 开工前：把最新的拿下来
git pull

# ② 开一条属于自己的分支
git switch -c feat/player-movement

# ③ 干活……中间随时本地按 F5 跑一下

# ④ 存一次档（只加自己改的文件！）
git add scenes/player/player.tscn scenes/player/player.gd
git commit -m "feat: 增加玩家基础移动"

# ⑤ 传到 GitHub
git push -u origin feat/player-movement

# ⑥ 去 GitHub 网页点 "New Pull Request"，等队友看过、同意后合并

# ⑦ 合并完，回到 main 并拉最新
git switch main
git pull
```

用 **GitHub Desktop** 的话，每步都有对应按钮：Commit → Push → Create Pull Request。不用背命令。

---

## 5. 存档说明怎么写（提交信息）

格式：`类型: 一句话`

| 类型 | 什么时候用 | 例子 |
| --- | --- | --- |
| `feat` | 加新功能 | `feat: 增加清扫者巡逻` |
| `fix` | 修 bug | `fix: 修复死亡后门打不开` |
| `docs` | 改文档 | `docs: 更新 03 规则的重试说明` |
| `art` | 加 / 改美术 | `art: 加入清扫者待机帧` |
| `refactor` | 改代码结构，不改功能 | `refactor: 抽出伤害计算` |
| `chore` | 杂项（配置、依赖） | `chore: 忽略构建目录` |

**为什么写这个**：一周后你想找"门是什么时候坏的"，看提交信息就能定位，不用翻代码。

---

## 6. 打版本号 tag —— 这就是"选一个版本继续做"的办法

每做出一个能玩的里程碑，打个 tag：

```bash
git tag -a v0.1 -m "最小可运行主场景"
git push origin v0.1
```

以后每到一个能玩节点，依次打 `v0.2`、`v0.3`……

### 场景 A：这次改动不满意，想退回上一个好版本

```bash
git tag                              # 先看看有哪些版本

# 从 v0.1 另开一条分支，在旧版本基础上继续做（原来的 main 一点都不动）
git switch -c recover/v0.1 v0.1
```

**关键点：旧版本永远都在。回退不是"删掉现在的"，而是"从旧的另开一条路"。**

### 场景 B：某人这次改的完全不行，想整个撤掉

在 GitHub 上找到那次提交，点 **Revert**。它会自动生成一个"撤销这次改动"的新提交，历史不会丢，也不会影响别人的工作。

---

## 7. 共享文件清单（动之前必须在群里说一声）

这些文件一改，可能影响所有人：

- `project.godot`（工程配置）
- 输入映射 / Autoload / 碰撞层（都写在 `project.godot` 里）
- 公共 TileSet
- `scenes/main.tscn`（主场景）

**还有一条 Godot 特有的坑：**

> **同一个 `.tscn` 场景，同一时间只能一个人改。**
> 场景文件本质是文本，两个人同时改几乎必定冲突。要改同一个场景，先在群里喊一声"我改 XX 场景了"，改完立刻提交。

---

## 8. 冲突了怎么办（别慌）

冲突的意思是：你和别人改了**同一行**，Git 不知道听谁的，于是标出来让你决定。

1. 打开有冲突的文件，找 `<<<<<<<`、`=======`、`>>>>>>>` 这三行标记；
2. 中间夹着的就是两个版本，**手动留下你要的内容，把三行标记删掉**；
3. 重新提交。

**不要直接"覆盖别人的成果"。** 看不懂就拉着改那一块的人一起看，这是最省事的办法。

---

## 9. 常见问题速查

| 情况 | 怎么办 |
| --- | --- |
| push 失败，说"落后了" | 先 `git pull`，再 push |
| 想放弃当前还没提交的改动 | GitHub Desktop 里点 **Discard changes** |
| 提交信息写错了、还没推 | `git commit --amend`（已经推了就另提一次，别改历史） |
| 想看看某文件以前长什么样 | GitHub 网页 → 该文件 → **History** |
| 忘了自己改了什么 | GitHub Desktop 会列出所有未提交改动 |

---

## 10. 新人上手 3 步

1. 装 **GitHub Desktop**（自带 Git LFS，不用单独装）；
2. 用 GitHub Desktop 登录 → File → Clone repository → 选 `borrowed-light`；
3. 打开 Godot，导入 `project.godot`，按 F5 能跑起来就算成功。

> ⚠️ **不要用 GitHub 网页的 "Download ZIP" 下载项目。** 那样下到的只是一堆文件副本，没有历史、不能 pull/push。必须用 clone。

---

## 附录 · 配套文件放在哪、有什么用

| 文件 | 位置 | 作用 |
| --- | --- | --- |
| `.gitattributes` | 仓库根目录 | 统一换行符，避免 Windows / macOS 之间整行都被标成改动；并注明何时才需要启用 Git LFS |
| `.github/pull_request_template.md` | 仓库根目录下的 `.github/` | 每次提 PR 时自动带出的检查清单，逼着大家写"怎么验证的" |
| `.gitignore` | 仓库根目录 | 告诉 Git 哪些文件不用管（`.godot/` 缓存、`.DS_Store`、构建产物等） |
| `docs/version_control.md` | 本文 | 手册本体 |

> **关于 Git LFS：现阶段不用。** 我们的素材是像素图和小音效，体积很小，普通 Git 完全够用。等出现「单个素材 > 10MB」或「仓库总量 > 100MB」时再启用——那时每个人要先装 `git-lfs` 并执行 `git lfs install`（macOS 用 `brew install git-lfs`；GitHub Desktop 自带，无需单装）。

---

## 需要 GitHub 网页上做的设置（让规范真正生效）

光有文档拦不住人，要在 GitHub 上设几道"硬门槛"：

1. **邀请 4 个人**，并在 Settings → Collaborators 给他们 **Write** 权限；
2. **保护 `main` 分支**：Settings → Branches → Add branch protection rule
   - 勾选 **Require a pull request before merging**（禁止直接 push 到 main）
   - 勾选 **Require approvals = 1**（必须有人看过）
   - 这两条一开，第 2 条铁律就从"口头约定"变成"系统强制"；
3. 在 Settings → General 里打开 **Issues**，用 Issues / Projects 当任务看板（对应 README 里的 待做 → 进行中 → 待检查 → 已完成）。

做完这三条，你要的那三件事就全部有保障了：

| 你想要的 | 靠什么保障 |
| --- | --- |
| 别人改了我知道 | 三条分支 + 每次 push 都能看到 diff |
| 找不回原来的版本 | `main` 只放能玩的版本 + 打 tag |
| 想选一个版本继续做 | tag 上 `git switch -c` 另开分支，旧版本原地不动 |
| 没人能偷偷坏掉主干 | main 分支保护（禁止直接 push） |
