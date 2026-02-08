# Blog 一键部署

基于 Caddy 的静态博客一键部署方案，自动 HTTPS，零配置证书管理。

## 为什么选择 Caddy？

相比 Nginx，Caddy 提供：

1. **零配置 HTTPS** - 自动获取和续期 Let's Encrypt 证书
2. **无需 certbot** - 内置证书管理，无需额外工具
3. **无需 cron** - 自动续期，无需手动配置定时任务
4. **现代协议** - 开箱即用的 HTTP/2 和 HTTP/3
5. **配置简单** - Caddyfile 语法比 nginx.conf 更简洁
6. **自动重载** - 配置更改后自动生效

## 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/geekspeng/blog-nginx.git
cd blog-nginx
```

### 2. 配置环境变量

```bash
cp .env.example .env
vi .env
```

编辑 `.env` 文件，配置您的域名和邮箱：

```env
DOMAIN=your-domain.com
EMAIL=your-email@example.com
WEB_ROOT=/var/www/html
```

### 3. 一键部署

```bash
chmod +x deploy-caddy.sh
./deploy-caddy.sh
```

脚本会自动完成以下操作：
- 检测操作系统并安装 Caddy
- 自动配置 HTTPS（无需手动申请证书）
- 部署静态网站
- 配置防火墙规则

## 支持的操作系统

| 系统 | 状态 |
|------|------|
| Ubuntu / Debian | ✅ |
| CentOS / RHEL / Fedora | ✅ |
| 阿里云龙蜥 | ✅ |
| 腾讯云 OpenCloudOS | ✅ |
| 华为 openEuler | ✅ |
| 麒麟 | ✅ |
| 统信 UOS | ✅ |

## 目录结构

```
blog-nginx/
├── deploy-caddy.sh          # Caddy 部署脚本
├── .env.example             # 环境变量示例
├── cert/                    # SSL 证书目录（可选）
└── html/                    # 静态网页目录
    └── index.html          # 网站首页
```

## 常用命令

### Caddy 服务管理

```bash
# 查看 Caddy 状态
sudo systemctl status caddy

# 重启 Caddy
sudo systemctl restart caddy

# 重载 Caddy 配置
sudo systemctl reload caddy

# 查看 Caddy 日志
sudo journalctl -u caddy -f

# 验证 Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
```

### 配置文件管理

```bash
# 编辑 Caddyfile
sudo vi /etc/caddy/Caddyfile

# 验证配置
sudo caddy validate --config /etc/caddy/Caddyfile

# 重载配置
sudo systemctl reload caddy
```

## Caddyfile 配置

默认配置文件位置：`/etc/caddy/Caddyfile`

```
your-domain.com {
    # 自动 HTTPS
    tls your@email.com

    # 网站根目录
    root * /var/www/html

    # 文件服务器
    file_server browse

    # 编码压缩
    encode gzip zstd

    # 安全头部
    header {
        Strict-Transport-Security "max-age=31536000"
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
    }
}
```

## 证书管理

Caddy 自动处理证书的申请和续期，**无需手动干预**。

**证书位置：** `/var/lib/caddy/certificates`

**特性：**
- 启动时自动申请证书
- 自动续期（在证书到期前）
- 无需配置 cron 任务
- 支持多个域名和 SANs

**查看证书信息：**
```bash
# 证书由 Caddy 自动管理，通常不需要手动操作
# 如需查看，可检查证书目录
sudo ls -la /var/lib/caddy/certificates/
```

## 防火墙配置

部署脚本会自动配置防火墙规则。如果需要手动配置：

### firewalld (CentOS/RHEL/国产系统)

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### ufw (Ubuntu/Debian)

```bash
sudo ufw allow 'Caddy'
# 或
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

## 注意事项

1. **首次部署前**，请确保域名 DNS 已正确解析到服务器 IP
2. **80 和 443 端口**需要对外开放
3. 证书会自动申请，无需手动配置 certbot
4. 更换域名后，Caddy 会自动为新域名申请证书
5. 如有多个域名，可在 Caddyfile 中添加多个站点块

## 故障排查

### 服务无法访问

```bash
# 检查 Caddy 状态
sudo systemctl status caddy

# 验证配置文件
sudo caddy validate --config /etc/caddy/Caddyfile

# 查看详细日志
sudo journalctl -u caddy -n 50 --no-pager

# 检查端口监听
sudo netstat -tlnp | grep caddy
```

### 证书申请失败

**检查域名解析：**
```bash
# 检查域名是否正确解析
ping your-domain.com
nslookup your-domain.com
```

**检查端口占用：**
```bash
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443
```

**停止冲突服务：**
```bash
# 如果有其他服务占用 80/443 端口
sudo systemctl stop nginx    # 停止 Nginx
sudo systemctl stop apache2  # 停止 Apache
```

### 权限问题

```bash
# 修复网站文件权限
sudo chown -R caddy:caddy /var/www/html
sudo chmod -R 755 /var/www/html
```

### 查看实时日志

```bash
# Caddy 系统日志
sudo journalctl -u caddy -f

# 访问日志（如果配置了文件输出）
sudo tail -f /var/log/caddy/*.log
```

## 卸载

```bash
# 停止服务
sudo systemctl stop caddy
sudo systemctl disable caddy

# 卸载 Caddy
# Ubuntu/Debian
sudo apt-get remove caddy

# CentOS/RHEL/国产系统
sudo dnf remove caddy
# 或
sudo yum remove caddy

# 删除配置文件（可选）
sudo rm -rf /etc/caddy
sudo rm -rf /var/lib/caddy
```

## 进阶配置

### 多站点配置

在 `/etc/caddy/Caddyfile` 中添加多个站点：

```
site1.com {
    root * /var/www/site1
    file_server
}

site2.com {
    root * /var/www/site2
    file_server
}
```

### 反向代理

```
your-domain.com {
    # 前端静态文件
    root * /var/www/html
    file_server

    # API 反向代理
    handle /api/* {
        reverse_proxy localhost:5000
    }
}
```

### 重定向到 HTTPS

Caddy 默认自动启用 HTTPS，HTTP 请求会自动重定向。如需自定义：

```
http://your-domain.com {
    redir https://your-domain.com{uri} permanent
}

https://your-domain.com {
    # ... 你的配置
}
```

## 参考资源

- [Caddy 官方文档](https://caddyserver.com/docs/)
- [Caddyfile 概念](https://caddyserver.com/docs/caddyfile/concepts)
- [自动 HTTPS](https://caddyserver.com/docs/automatic-https)

## 许可证

MIT
