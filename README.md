# Web-Obsidian 部署指南

Web-Obsidian 是一套将 LinuxServer/Obsidian 容器与 Tailscale Serve 组合使用的部署方案，可在任意联网环境通过 Tailnet 安全访问个人的 Obsidian Vault。本仓库提供了 `docker-compose.yml`、`.env` 模板以及一键化脚本，帮助你快速完成环境配置与日常维护。

## 功能亮点

- **Docker Compose**：复用 [linuxserver/docker-obsidian](https://github.com/linuxserver/docker-obsidian) 镜像，内置 `CUSTOM_USER/PASSWORD`、`/config`、`/vault` 等参数。
- **Tailscale Serve**：通过 [tailscale](https://tailscale.com) 的反向代理，在 Tailnet 内或经 MagicDNS 暴露 3000/3001/8082 等端口。
- **自动脚本**：`env-setup.*` 引导生成 `.env`，`reset-obsidian.*` 用于一键重置 Tailscale 端口、重启 Docker、检测连通性并给出 Tailnet 访问地址。

## 目录结构

```
.
├─ docker-compose.yml           # 主服务定义
├─ env.example / env.md         # 环境变量模板与说明
├─ env-setup.ps1 / env-setup.sh # 交互式生成 .env
├─ reset-obsidian.ps1/.sh       # 停机→重置→重启→检测
└─ Skill Stack/...              # 详细操作手册
```

## 环境准备

1. **安装 Docker Desktop**（Windows/macOS）或 Docker Engine（Linux），确保启用 WSL2（Windows）。
2. **安装 Tailscale** 并登录帐号，可使用 `tailscale ip -4` 查看分配的 100.x 地址或 MagicDNS。
3. **克隆本仓库**：`git clone <repo>`，并进入根目录。

## 配置步骤

1. 运行 `env-setup.ps1`（PowerShell）或 `env-setup.sh`（Bash）：
   - 填写 `APP_DIR`（绝对路径，Windows 建议使用正斜杠）
   - 设置 `CUSTOM_USER` / `PASSWORD`
   - 指定 `COMPOSE_PROJECT_NAME`（目录名包含中文时尤为重要）
   - 根据 `tailscale ip -4` 填写 `TAILSCALE_IP`
2. 如需自定义端口，可在 `.env` 中添加 `LOCAL_PORTS=3000,3001,8082` 并对应地修改 `docker-compose.yml`。
3. 首次部署：`docker compose up -d`。
4. 参考 `Skill Stack/…/远程obsidian教程.md`，了解与 Tailscale Serve 配合的完整流程。

## 一键重置脚本

```powershell
pwsh ./reset-obsidian.ps1
```

```bash
bash ./reset-obsidian.sh
```

脚本会：
- 停止当前 Compose 容器，清理遗留的 `obsidian` 容器
- `tailscale serve reset` 并重启 Docker（如有需要）
- 使用 `.env` 中的配置重新启动容器，等待 3000 端口返回任意 HTTP 状态（含 401）
- 自动重新发布 Tailscale Serve，输出 `Tailnet access: http://<TAILSCALE_IP>:3000`

## 致谢

- 特别感谢 [linuxserver/docker-obsidian](https://github.com/linuxserver/docker-obsidian) 项目提供稳定的 Obsidian Docker 镜像；本项目的 Compose 配置与脚本均基于其镜像实现。
- 感谢 [Tailscale](https://tailscale.com) 提供简洁的零配置 WireGuard 网络与 `tailscale serve` 功能，使得远程访问 Web Obsidian 变得轻松可靠。

如果你在使用过程中有改进建议或需要帮助，欢迎提交 issue 或 PR。祝使用愉快！
