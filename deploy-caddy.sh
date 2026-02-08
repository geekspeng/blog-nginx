#!/bin/bash

# 一键部署脚本 - 使用 Caddy Web 服务器
# Caddy 自动处理 HTTPS 证书（无需 certbot）
# 支持系统: Ubuntu/Debian (apt) 和 CentOS/RHEL/Fedora (yum)
# 使用方法: ./deploy-caddy.sh

set -e  # 遇到错误时退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印信息函数
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        error "无法检测操作系统类型"
        exit 1
    fi

    info "检测到操作系统: $OS $OS_VERSION"

    case $OS in
        ubuntu|debian|deepin|uos)
            PKG_MANAGER="apt"
            ;;
        centos|rhel|fedora|anolis|opencloudos|openEuler|kylin)
            PKG_MANAGER="yum"
            ;;
        *)
            error "不支持的操作系统: $OS"
            error "支持系统: Ubuntu, Debian, CentOS, RHEL, Fedora, 阿里云龙蜥, 腾讯云 OpenCloudOS, 华为 openEuler, 麒麟, 统信 UOS"
            exit 1
            ;;
    esac
}

# 加载配置
load_config() {
    info "加载配置..."

    if [ ! -f ".env" ]; then
        warn ".env 文件不存在，使用默认配置"
        cat > .env << EOF
# 域名配置
DOMAIN=mango-reader.cn

# 邮箱配置（用于 SSL 证书申请）
EMAIL=geekspeng@163.com

# 网站根目录
WEB_ROOT=/var/www/html

# HTTP 端口
HTTP_PORT=80

# HTTPS 端口
HTTPS_PORT=443
EOF
        error "请先编辑 .env 文件，配置您的域名和邮箱"
        exit 1
    fi

    source .env

    if [ "$DOMAIN" = "your-domain.com" ]; then
        error "请在 .env 文件中配置正确的域名"
        exit 1
    fi

    info "配置加载完成 - 域名: $DOMAIN"
}

# 安装 Caddy
install_caddy() {
    info "检查 Caddy 安装状态..."

    if command -v caddy &> /dev/null; then
        info "Caddy 已安装: $(caddy version | head -n1)"
        return
    fi

    info "开始安装 Caddy..."

    if [ "$PKG_MANAGER" = "apt" ]; then
        install_caddy_apt
    elif [ "$PKG_MANAGER" = "yum" ]; then
        install_caddy_yum
    fi

    info "Caddy 安装完成"
}

# 使用 apt 安装 Caddy (Ubuntu/Debian)
install_caddy_apt() {
    info "添加 Caddy 官方仓库..."

    # 安装依赖
    sudo apt-get update
    sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl

    # 添加 GPG 密钥
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
        | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

    # 添加仓库
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
        | sudo tee /etc/apt/sources.list.d/caddy-stable.list

    # 安装
    sudo apt-get update
    sudo apt-get install -y caddy
}

# 使用 yum/dnf 安装 Caddy (CentOS/RHEL/Fedora/国产系统)
install_caddy_yum() {
    info "安装 Caddy..."

    # 检测系统类型，选择对应的包管理器插件
    if [ "$OS" = "fedora" ]; then
        # Fedora 使用 dnf5-plugins
        sudo dnf install -y dnf5-plugins
    else
        # CentOS/RHEL 使用 dnf-plugins-core
        if command -v dnf &> /dev/null; then
            sudo dnf install -y dnf-plugins-core
        else
            sudo yum install -y yum-utils
        fi
    fi

    # 启用 Caddy COPR 仓库
    if command -v dnf &> /dev/null; then
        sudo dnf copr enable @caddy/caddy -y
        sudo dnf install -y caddy
    else
        # yum 系统可能需要手动配置
        warn "系统使用 yum，尝试从 COPR 安装..."
        sudo yum install -y dnf
        sudo dnf copr enable @caddy/caddy -y
        sudo dnf install -y caddy
    fi

    info "Caddy 安装完成: $(caddy version | head -n1)"
}

# 配置 Caddy
configure_caddy() {
    info "配置 Caddy..."

    # 创建必要的目录
    sudo mkdir -p "$WEB_ROOT"
    sudo mkdir -p /var/log/caddy
    sudo mkdir -p /etc/caddy

    # 设置目录权限
    sudo chown -R caddy:caddy "$WEB_ROOT" 2>/dev/null || \
    sudo chown -R www-data:www-data "$WEB_ROOT" 2>/dev/null

    sudo chown -R caddy:caddy /var/log/caddy 2>/dev/null || \
    sudo chown -R www-data:www-data /var/log/caddy 2>/dev/null

    sudo chmod 755 "$WEB_ROOT"
    sudo chmod 755 /var/log/caddy

    # 复制静态文件
    if [ -d "./html" ] && [ "$(ls -A ./html)" ]; then
        info "复制静态文件到 $WEB_ROOT..."
        sudo cp -r ./html/* "$WEB_ROOT"/
    fi

    # 生成 Caddyfile
    generate_caddyfile

    info "Caddy 配置完成"
}

# 生成 Caddyfile
generate_caddyfile() {
    info "生成 Caddyfile..."

    CADDYFILE="/etc/caddy/Caddyfile"

    # 备份原配置
    if [ -f "$CADDYFILE" ]; then
        sudo cp "$CADDYFILE" "${CADDYFILE}.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    # 生成新配置
    sudo tee "$CADDYFILE" > /dev/null << EOF
# Caddy 自动配置文件
# Caddy 会自动获取和续期 SSL 证书

# 通过 IP 访问（使用自签名证书）
:443 {
    # 使用自签名证书（浏览器会显示警告，需要手动信任）
    tls internal {
        on_demand
    }

    # 网站根目录
    root * $WEB_ROOT

    # 文件服务器
    file_server browse

    # 编码
    encode gzip zstd

    # 静态文件缓存
    @static {
        path *.jpg *.jpeg *.png *.gif *.ico *.css *.js *.svg *.woff *.woff2 *.ttf *.eot
    }
    header @static Cache-Control "public, max-age=2592000, immutable"

    # 日志
    log {
        output file /var/log/caddy/ip_access.log {
            roll_size 100mb
            roll_keep 5
        }
        format json
    }

    # SPA 支持（可选）
    try_files {path} /index.html
}

# IP 的 HTTP 自动重定向到 HTTPS
:80 {
    # 重定向到 HTTPS
    redir https://{host}{uri} permanent
}

# 通过域名访问（支持 HTTPS）
$DOMAIN {
    # 自动 HTTPS
    tls $EMAIL

    # 网站根目录
    root * $WEB_ROOT

    # 文件服务器
    file_server browse

    # 编码
    encode gzip zstd

    # 静态文件缓存
    @static {
        path *.jpg *.jpeg *.png *.gif *.ico *.css *.js *.svg *.woff *.woff2 *.ttf *.eot
    }
    header @static Cache-Control "public, max-age=2592000, immutable"

    # 安全头部
    header {
        # 启用 HSTS
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"

        # 防止点击劫持
        X-Frame-Options "SAMEORIGIN"

        # 防止 MIME 类型嗅探
        X-Content-Type-Options "nosniff"

        # XSS 保护
        X-XSS-Protection "1; mode=block"

        # Referrer 策略
        Referrer-Policy "strict-origin-when-cross-origin"
    }

    # 日志
    log {
        output file /var/log/caddy/${DOMAIN}_access.log {
            roll_size 100mb
            roll_keep 5
        }
        format json
    }

    # SPA 支持（可选）
    try_files {path} /index.html
}

# API 代理（可选，如果需要）
# $DOMAIN/api {
#     reverse_proxy localhost:5000
# }

# HTTP 自动重定向到 HTTPS（Caddy 默认行为）
# http://$DOMAIN {
#     redir https://$DOMAIN{uri} permanent
# }
EOF

    # 创建日志目录
    sudo mkdir -p /var/log/caddy
    sudo chown -R caddy:caddy /var/log/caddy 2>/dev/null || \
    sudo chown -R www-data:www-data /var/log/caddy 2>/dev/null

    info "Caddyfile 已生成: $CADDYFILE"
}

# 启动 Caddy
start_caddy() {
    info "启动 Caddy 服务..."

    # 确保所有必要目录存在并有正确权限
    sudo mkdir -p /var/log/caddy
    sudo mkdir -p /etc/caddy

    # 尝试设置 caddy 用户权限，如果失败则尝试 www-data
    if id caddy &>/dev/null; then
        sudo chown -R caddy:caddy /var/log/caddy
    elif id www-data &>/dev/null; then
        sudo chown -R www-data:www-data /var/log/caddy
    else
        # 如果都不存在，使用 root 权限但设置为可写
        sudo chmod 777 /var/log/caddy
    fi

    sudo chmod 755 /var/log/caddy

    # 提前创建日志文件并设置权限
    sudo touch /var/log/caddy/ip_access.log
    sudo touch /var/log/caddy/${DOMAIN}_access.log
    if id caddy &>/dev/null; then
        sudo chown caddy:caddy /var/log/caddy/*.log
    elif id www-data &>/dev/null; then
        sudo chown www-data:www-data /var/log/caddy/*.log
    fi
    sudo chmod 644 /var/log/caddy/*.log

    # 验证配置
    info "验证 Caddy 配置..."
    sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

    # 先停止可能存在的服务
    sudo systemctl stop caddy 2>/dev/null || true

    # 启动服务
    sudo systemctl start caddy

    # 等待一下，检查服务状态
    sleep 2
    if sudo systemctl is-active --quiet caddy; then
        sudo systemctl enable caddy
        info "Caddy 服务已启动"
    else
        error "Caddy 服务启动失败，查看日志:"
        sudo journalctl -u caddy -n 20 --no-pager
        exit 1
    fi
}

# 配置防火墙
configure_firewall() {
    info "检查防火墙配置..."

    # 检查 firewalld
    if command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
        info "配置 firewalld..."
        sudo firewall-cmd --permanent --add-service=http
        sudo firewall-cmd --permanent --add-service=https
        sudo firewall-cmd --reload
    fi

    # 检查 ufw
    if command -v ufw &> /dev/null; then
        info "配置 ufw..."
        sudo ufw allow 'Caddy'
    fi
}

# 显示部署信息
show_deployment_info() {
    echo ""
    echo "========================================"
    info "部署完成！"
    echo ""
    echo "访问地址:"
    echo "  http://$DOMAIN"
    echo "  https://$DOMAIN"
    echo ""
    echo "配置信息:"
    echo "  Caddyfile: /etc/caddy/Caddyfile"
    echo "  网站根目录: $WEB_ROOT"
    echo "  SSL 证书: 自动管理（Caddy 内置）"
    echo ""
    echo "管理命令:"
    echo "  查看 Caddy 状态: sudo systemctl status caddy"
    echo "  重启 Caddy: sudo systemctl restart caddy"
    echo "  重载 Caddy: sudo systemctl reload caddy"
    echo "  查看 Caddy 日志: sudo journalctl -u caddy -f"
    echo "  验证配置: sudo caddy validate --config /etc/caddy/Caddyfile"
    echo ""
    echo "证书信息:"
    echo "  Caddy 自动获取和续期 Let's Encrypt 证书"
    echo "  证书存储位置: /var/lib/caddy/certificates"
    echo "  无需手动配置 certbot 或 cron 任务"
    echo ""
    echo "网站文件位置: $WEB_ROOT"
    echo "========================================"
}

# 主函数
main() {
    echo "========================================"
    echo "    Blog Caddy 一键部署脚本"
    echo "    （自动 HTTPS）"
    echo "========================================"
    echo ""

    detect_os
    load_config
    configure_firewall
    install_caddy
    configure_caddy
    start_caddy
    show_deployment_info
}

# 运行主函数
main "$@"
