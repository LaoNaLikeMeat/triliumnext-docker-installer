# TriliumNext Docker 一键安装脚本

一个功能完整的 **TriliumNext Notes** Docker 部署和管理脚本，支持多种 SSL 证书配置和完整的生命周期管理。

## 特性

* **一键部署**: 自动安装 Docker、Docker Compose 和 TriliumNext
* **智能管理**: 已安装时自动进入管理面板
* **多SSL支持**: 支持 HTTP、Let's Encrypt、Cloudflare 证书
* **完整管理**: 启动、停止、备份、恢复、更新等功能
* **安全卸载**: 多重确认的完全卸载功能
* **系统兼容**: 支持主流 Linux 发行版

## 系统要求

* **操作系统**: Ubuntu 18.04+, Debian 9+, CentOS 7+
* **内存**: 最少 512MB RAM，推荐 1GB+
* **存储**: 至少 1GB 可用空间
* **网络**: 能够访问 Docker Hub 和 GitHub

---

## 快速开始

### 下载并运行脚本

```bash
# 下载脚本
wget https://raw.githubusercontent.com/LaoNaLikeMeat/triliumnext-docker-installer/main/trilium-install.sh

# 或使用 curl
curl -O https://raw.githubusercontent.com/LaoNaLikeMeat/triliumnext-docker-installer/main/trilium-install.sh

# 设置执行权限
chmod +x trilium-install.sh

# 运行安装
./trilium-install.sh
```

---

## 首次安装流程

1. **系统检查**: 自动检测和安装 Docker、Docker Compose
2. **域名配置**: 输入你的域名（如 notes.example.com）
3. **SSL 选择**: 选择 SSL 证书类型
4. **端口设置**: 配置 HTTP/HTTPS 端口
5. **密码设置**: 设置管理员密码
6. **自动部署**: 脚本自动完成剩余配置

---

## SSL 证书配置

### 1. 不使用 SSL (仅 HTTP)

适用于内网环境或测试用途。

### 2. Let's Encrypt 自动证书

* 免费 SSL 证书
* 自动续期
* 需要域名可从公网访问

### 3. Cloudflare 证书

推荐用于已使用 Cloudflare 的用户。

#### 获取 Cloudflare 证书

1. 登录 Cloudflare 控制台
2. 选择你的域名
3. 进入 `SSL/TLS` → `Origin Certificates`
4. 点击 `Create Certificate`
5. 选择域名覆盖范围（推荐通配符）
6. 下载证书和私钥文件

#### 证书文件格式

* **证书文件**: `.crt` 或 `.pem` 格式，包含完整证书链
* **私钥文件**: `.key` 格式

---

## 管理功能

再次运行脚本会进入管理面板：

```bash
./trilium-install.sh
```

### 管理选项

| 选项 | 功能   | 说明                |
| -- | ---- | ----------------- |
| 1  | 启动服务 | 启动 TriliumNext 服务 |
| 2  | 停止服务 | 停止 TriliumNext 服务 |
| 3  | 重启服务 | 重启 TriliumNext 服务 |
| 4  | 查看状态 | 显示服务运行状态          |
| 5  | 实时日志 | 查看服务实时日志          |
| 6  | 更新版本 | 更新到最新版本           |
| 7  | 备份数据 | 备份 TriliumNext 数据 |
| 8  | 恢复数据 | 从备份恢复数据           |
| 9  | 重新配置 | 重新配置安装            |
| 10 | 完全卸载 | 删除所有数据和配置         |

---

## 命令行管理

安装后也可以使用系统命令：

```bash
triliumnext start    # 启动服务
triliumnext stop     # 停止服务
triliumnext restart  # 重启服务
triliumnext logs     # 查看日志
triliumnext status   # 查看状态
triliumnext backup   # 备份数据
triliumnext update   # 更新版本
```

---

## 数据备份与恢复

### 自动备份

```bash
# 设置定时备份（每天凌晨2点）
crontab -e
# 添加：
0 2 * * * /usr/local/bin/triliumnext backup
```

### 手动备份

```bash
triliumnext backup
```

备份文件保存在 `/backup/triliumnext/` 目录。

### 数据恢复

```bash
triliumnext restore /backup/triliumnext/triliumnext-backup-20240127_020001.tar.gz
```

---

## 目录结构

```
/opt/triliumnext/
├── docker-compose.yml    # Docker Compose 配置
├── trilium-manage.sh     # 管理脚本
├── data/                 # TriliumNext 数据目录
└── config/               # 配置文件目录
    ├── nginx/            # Nginx 配置
    └── certs/            # SSL 证书（如果使用）
```

---

## 端口配置

* **默认 HTTP 端口**: 80
* **默认 HTTPS 端口**: 443
* **TriliumNext 内部端口**: 8080

如果默认端口被占用，安装时可以自定义端口。

---

## 故障排除

### 常见问题

#### 1. Docker 服务未启动

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

#### 2. 端口被占用

```bash
# 检查端口占用
netstat -tlnp | grep :80
# 停止占用进程或更换端口
```

#### 3. 域名解析问题

```bash
nslookup your-domain.com
```

#### 4. SSL 证书问题

```bash
openssl x509 -in cert.pem -text -noout
```

### 查看日志

```bash
# 查看服务日志
triliumnext logs

# 查看特定服务日志
cd /opt/triliumnext
docker-compose logs triliumnext
docker-compose logs nginx
```

---

## 安全建议

* **强密码**: 使用复杂的管理员密码
* **防火墙**: 只开放必要端口
* **HTTPS**: 生产环境务必使用 SSL
* **备份**: 定期备份数据
* **更新**: 保持系统和应用最新

---

## 系统要求检查

脚本会自动检查：

* 操作系统兼容性
* 系统内存大小
* 可用磁盘空间
* CPU 架构支持

---

## 更新日志

### v1.0.0

* 初始版本发布
* 支持基本安装和管理功能
* 支持三种 SSL 配置方式

---

## 贡献指南

欢迎提交 Issue 和 Pull Request。

### 开发环境

```bash
git clone https://github.com/LaoNaLikeMeat/triliumnext-docker-installer.git
cd triliumnext-docker-installer
```

### 测试

```bash
# 测试语法
bash -n trilium-install.sh

# 测试安装
./trilium-install.sh
```

---

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件。

---

## 支持

* [GitHub Issues](https://github.com/LaoNaLikeMeat/triliumnext-docker-installer/issues)
* [TriliumNext 官方文档](https://github.com/TriliumNext/Notes/wiki)
* [Docker 官方文档](https://docs.docker.com/)

---

## 相关链接

* [TriliumNext Notes](https://github.com/TriliumNext/Notes) - 官方项目
* [Docker Hub - TriliumNext](https://hub.docker.com/r/triliumnext/notes) - 官方镜像
* [Cloudflare](https://www.cloudflare.com/) - SSL 证书服务
* [Let's Encrypt](https://letsencrypt.org/) - 免费 SSL 证书

