#!/bin/bash

# Trilium Notes Docker 一键安装脚本 - 优化版
# 支持交互式配置，包括Cloudflare证书配置
# 已切换镜像源到 triliumnext/notes，并默认使用 latest 版本
# 集成智能修复功能，预防和解决Docker Compose ContainerConfig错误

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 全局变量
TRILIUM_VERSION="latest"
INSTALL_DIR="/opt/trilium"
DATA_DIR="/opt/trilium/data"
CONFIG_DIR="/opt/trilium/config"
DOMAIN=""
EMAIL=""
USE_SSL=false
SSL_TYPE=""
CF_CERT_PATH=""
CF_KEY_PATH=""
TRILIUM_PORT="8080"
HTTP_PORT="80"
HTTPS_PORT="443"
ADMIN_PASSWORD=""
COMPOSE_CMD=""  # 用于存储正确的compose命令

# 显示横幅
show_banner() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${WHITE}                  Trilium Notes Docker 一键安装脚本 - 优化版              ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${WHITE}                    支持 Cloudflare 证书 & 智能错误修复                  ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# 显示信息
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# 显示成功信息
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 显示警告
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 显示错误
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        warning "正在使用root用户运行脚本"
        info "建议创建普通用户以提高安全性"
    fi
}

# 检查Trilium是否已安装
check_existing_installation() {
    if [[ -f "$INSTALL_DIR/docker-compose.yml" ]] && [[ -d "$DATA_DIR" ]]; then
        return 0  # 已安装
    else
        return 1  # 未安装
    fi
}

# 完全卸载Trilium
uninstall_trilium() {
    echo
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${WHITE}                          完全卸载 Trilium                               ${RED}║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    echo -e "${YELLOW}警告: 此操作将完全删除Trilium及其所有数据!${NC}"
    echo -e "${RED}注意: 数据删除后无法恢复!${NC}"
    echo
    echo "卸载内容包括:"
    echo "• 停止并删除所有Docker容器"
    echo "• 删除Docker镜像"
    echo "• 删除所有数据文件"
    echo "• 删除配置文件"
    echo "• 删除管理脚本"
    echo "• 清理防火墙规则"
    echo
    
    # 多重确认
    read -p "您确定要完全卸载Trilium吗？(输入 'yes' 确认): " confirm1
    if [[ "$confirm1" != "yes" ]]; then
        info "卸载已取消"
        return 0
    fi
    
    echo
    read -p "最后确认：这将删除所有数据，无法恢复！(输入 'DELETE' 确认): " confirm2
    if [[ "$confirm2" != "DELETE" ]]; then
        info "卸载已取消"
        return 0
    fi
    
    echo
    info "开始卸载Trilium..."
    
    # 停止服务
    if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
        cd "$INSTALL_DIR"
        info "停止Trilium服务..."
        eval "$COMPOSE_CMD down -v" 2>/dev/null || true
        
        # 删除Docker镜像
        info "删除Docker镜像..."
        docker rmi zadam/trilium:${TRILIUM_VERSION} 2>/dev/null || true
        docker rmi triliumnext/notes:${TRILIUM_VERSION} 2>/dev/null || true
        docker rmi nginx:alpine 2>/dev/null || true
        docker rmi certbot/certbot 2>/dev/null || true
    fi
    
    # 删除安装目录
    if [[ -d "$INSTALL_DIR" ]]; then
        info "删除安装目录..."
        rm -rf "$INSTALL_DIR"
    fi
    
    # 删除备份目录
    if [[ -d "/backup/trilium" ]]; then
        read -p "是否同时删除备份文件？(y/N): " delete_backup
        if [[ "$delete_backup" =~ ^[Yy]$ ]]; then
            info "删除备份目录..."
            rm -rf "/backup/trilium"
        fi
    fi
    
    # 删除管理脚本
    if [[ -f "/usr/local/bin/trilium" ]]; then
        info "删除管理脚本..."
        rm -f "/usr/local/bin/trilium"
    fi
    
    # 清理防火墙规则
    info "清理防火墙规则..."
    if command -v ufw &> /dev/null; then
        ufw delete allow 80/tcp 2>/dev/null || true
        ufw delete allow 443/tcp 2>/dev/null || true
        ufw delete allow 8080/tcp 2>/dev/null || true
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --remove-port=80/tcp 2>/dev/null || true
        firewall-cmd --permanent --remove-port=443/tcp 2>/dev/null || true
        firewall-cmd --permanent --remove-port=8080/tcp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
    fi
    
    # 清理Docker网络和卷
    info "清理Docker资源..."
    docker network prune -f 2>/dev/null || true
    docker volume prune -f 2>/dev/null || true
    
    echo
    success "Trilium卸载完成！"
    echo
    echo -e "${WHITE}已清理的内容:${NC}"
    echo "✓ Docker容器和镜像"
    echo "✓ 安装目录和数据文件"
    echo "✓ 配置文件"
    echo "✓ 管理脚本"
    echo "✓ 防火墙规则"
    echo "✓ Docker网络和卷"
    
    echo
    info "如需重新安装，请再次运行安装脚本"
    exit 0
}

# 显示管理面板
show_management_panel() {
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${WHITE}                    Trilium Notes 管理面板                               ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # 检查服务状态
    cd "$INSTALL_DIR"
    if eval "$COMPOSE_CMD ps" 2>/dev/null | grep -q "Up"; then
        echo -e "${GREEN}● 服务状态: 运行中${NC}"
    else
        echo -e "${RED}● 服务状态: 已停止${NC}"
    fi
    
    # 显示访问信息
    if [[ -f "$CONFIG_DIR/nginx/nginx.conf" ]]; then
        local domain=$(grep "server_name" "$CONFIG_DIR/nginx/nginx.conf" | head -1 | awk '{print $2}' | sed 's/;//')
        if grep -q "listen 443" "$CONFIG_DIR/nginx/nginx.conf"; then
            echo -e "${WHITE}● 访问地址: ${GREEN}https://$domain${NC}"
        else
            echo -e "${WHITE}● 访问地址: ${GREEN}http://$domain${NC}"
        fi
    fi
    
    echo
    echo -e "${WHITE}请选择操作:${NC}"
    echo -e "${WHITE}1)${NC} 启动服务"
    echo -e "${WHITE}2)${NC} 停止服务"
    echo -e "${WHITE}3)${NC} 重启服务"
    echo -e "${WHITE}4)${NC} 查看服务状态"
    echo -e "${WHITE}5)${NC} 查看实时日志"
    echo -e "${WHITE}6)${NC} 智能更新Trilium版本"
    echo -e "${WHITE}7)${NC} 备份数据"
    echo -e "${WHITE}8)${NC} 恢复数据"
    echo -e "${WHITE}9)${NC} 重新配置/重新安装"
    echo -e "${WHITE}10)${NC} 完全卸载Trilium"
    echo -e "${WHITE}0)${NC} 退出"
    echo
    
    while true; do
        read -p "请选择操作 (0-10): " choice
        
        case $choice in
            1)
                manage_service "start"
                break
                ;;
            2)
                manage_service "stop"
                break
                ;;
            3)
                manage_service "restart"
                break
                ;;
            4)
                manage_service "status"
                break
                ;;
            5)
                manage_service "logs"
                break
                ;;
            6)
                manage_service "update"
                break
                ;;
            7)
                manage_service "backup"
                break
                ;;
            8)
                manage_service "restore"
                break
                ;;
            9)
                echo
                echo -e "${YELLOW}警告: 这将重新配置Trilium，现有配置将被覆盖！${NC}"
                read -p "确认继续重新安装? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    return 1  # 返回1表示重新安装
                else
                    show_management_panel
                    return 0
                fi
                ;;
            10)
                uninstall_trilium
                break
                ;;
            0)
                echo
                success "感谢使用 Trilium Docker 安装脚本！"
                exit 0
                ;;
            *)
                error "无效选择，请输入0-10"
                ;;
        esac
    done
}

# 智能更新函数 - 包含错误修复
update_trilium_with_fix() {
    info "智能更新Trilium到最新版本..."
    
    # 先创建备份
    info "创建数据备份..."
    local backup_dir="/backup/trilium"
    local date=$(date +%Y%m%d_%H%M%S)
    local backup_file="trilium-backup-before-update-$date.tar.gz"
    
    mkdir -p "$backup_dir"
    
    if eval "$COMPOSE_CMD ps" | grep -q "trilium.*Up"; then
        eval "$COMPOSE_CMD exec trilium tar -czf \"/tmp/$backup_file\" -C /home/node/trilium-data ."
        docker cp $(eval "$COMPOSE_CMD ps -q trilium"):/tmp/$backup_file "$backup_dir/"
        eval "$COMPOSE_CMD exec trilium rm \"/tmp/$backup_file\"" 2>/dev/null || true
        success "数据备份完成: $backup_dir/$backup_file"
    else
        warning "服务未运行，跳过在线备份，使用本地文件备份"
        if [[ -d "$DATA_DIR" ]]; then
            tar -czf "$backup_dir/$backup_file" -C "$DATA_DIR" . 2>/dev/null || true
            success "本地数据备份完成: $backup_dir/$backup_file"
        fi
    fi
    
    # 尝试正常更新
    info "拉取最新镜像..."
    if eval "$COMPOSE_CMD pull"; then
        info "镜像拉取成功，开始更新容器..."
        if eval "$COMPOSE_CMD up -d"; then
            success "更新完成！"
            return 0
        else
            warning "标准更新失败，开始智能修复..."
        fi
    else
        error "镜像拉取失败"
        return 1
    fi
    
    # 如果正常更新失败，开始修复流程
    show_update_fix_menu
}

# 更新修复菜单
show_update_fix_menu() {
    echo
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${WHITE}            更新失败 - 智能修复选项                          ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${RED}检测到更新失败，可能是 ContainerConfig 错误${NC}"
    echo
    echo "请选择修复方案:"
    echo -e "${WHITE}1)${NC} 强制重新创建容器 (推荐，最安全)"
    echo -e "${WHITE}2)${NC} 升级到 Docker Compose V2 并重试"
    echo -e "${WHITE}3)${NC} 完全清理 Docker 系统并重建"
    echo -e "${WHITE}4)${NC} 手动修复指导"
    echo -e "${WHITE}0)${NC} 取消修复"
    echo
    
    while true; do
        read -p "请选择修复方案 (0-4): " choice
        
        case $choice in
            1)
                fix_force_recreate
                break
                ;;
            2)
                fix_upgrade_compose_v2
                break
                ;;
            3)
                fix_complete_cleanup
                break
                ;;
            4)
                show_manual_fix_guide
                break
                ;;
            0)
                warning "修复已取消，Trilium 可能仍处于异常状态"
                return 1
                ;;
            *)
                error "无效选择，请输入0-4"
                ;;
        esac
    done
}

# 修复方案1：强制重新创建
fix_force_recreate() {
    info "执行方案1: 强制重新创建容器"
    
    # 停止并删除所有容器
    info "停止并删除现有容器..."
    eval "$COMPOSE_CMD down --volumes --remove-orphans" 2>/dev/null || true
    
    # 清理残留容器
    info "清理残留容器..."
    local project_name=$(basename "$INSTALL_DIR")
    docker ps -a --filter "label=com.docker.compose.project=${project_name}" --format "{{.ID}}" 2>/dev/null | xargs -r docker rm -f 2>/dev/null || true
    docker ps -a --filter "label=com.docker.compose.project=trilium" --format "{{.ID}}" 2>/dev/null | xargs -r docker rm -f 2>/dev/null || true
    
    # 重新创建并启动
    info "重新创建并启动服务..."
    if eval "$COMPOSE_CMD up -d --force-recreate"; then
        success "容器重新创建成功！"
        
        # 等待服务启动
        info "等待服务启动..."
        sleep 10
        
        # 检查服务状态
        if eval "$COMPOSE_CMD ps" | grep -q "Up"; then
            success "Trilium服务启动成功！"
        else
            warning "服务启动可能有问题，请检查日志"
            eval "$COMPOSE_CMD logs --tail=20"
        fi
    else
        error "重新创建失败"
        return 1
    fi
}

# 修复方案2：升级到 Docker Compose V2
fix_upgrade_compose_v2() {
    info "执行方案2: 升级到 Docker Compose V2"
    
    # 检查是否已经是 V2
    if docker compose version &> /dev/null; then
        success "已经在使用 Docker Compose V2"
        COMPOSE_CMD="docker compose"
    else
        warning "正在升级到 Docker Compose V2..."
        
        # 安装 Docker Compose V2 插件
        if command -v apt-get &> /dev/null; then
            apt-get update
            apt-get install -y docker-compose-plugin
        elif command -v yum &> /dev/null; then
            yum install -y docker-compose-plugin
        else
            # 手动安装
            info "手动安装 Docker Compose V2..."
            COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest 2>/dev/null | grep 'tag_name' | cut -d\" -f4 || echo "v2.21.0")
            mkdir -p ~/.docker/cli-plugins/
            curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" -o ~/.docker/cli-plugins/docker-compose 2>/dev/null
            chmod +x ~/.docker/cli-plugins/docker-compose
        fi
        
        if docker compose version &> /dev/null; then
            success "Docker Compose V2 安装成功"
            COMPOSE_CMD="docker compose"
        else
            error "Docker Compose V2 安装失败，回退到强制重新创建"
            fix_force_recreate
            return $?
        fi
    fi
    
    # 使用新的命令重新创建
    fix_force_recreate
}

# 修复方案3：完全清理
fix_complete_cleanup() {
    info "执行方案3: 完全清理 Docker 系统并重建"
    
    echo
    echo -e "${RED}警告: 这将清理所有未使用的 Docker 资源！${NC}"
    echo "这包括："
    echo "• 所有停止的容器"
    echo "• 所有未使用的网络"
    echo "• 所有未使用的镜像"
    echo "• 所有未使用的构建缓存"
    echo
    read -p "确认继续? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        info "操作已取消"
        return 1
    fi
    
    # 停止服务
    info "停止 Trilium 服务..."
    eval "$COMPOSE_CMD down" 2>/dev/null || true
    
    # 清理 Docker 系统
    info "清理 Docker 系统..."
    docker system prune -af
    docker volume prune -f 2>/dev/null || true
    docker network prune -f 2>/dev/null || true
    
    # 重新拉取镜像
    info "重新拉取镜像..."
    eval "$COMPOSE_CMD pull"
    
    # 重新启动
    info "重新启动服务..."
    if eval "$COMPOSE_CMD up -d"; then
        success "清理重建完成！"
        
        # 等待服务启动
        info "等待服务启动..."
        sleep 10
        
        # 检查服务状态
        if eval "$COMPOSE_CMD ps" | grep -q "Up"; then
            success "Trilium服务启动成功！"
        else
            warning "服务启动可能有问题，请检查日志"
        fi
    else
        error "重新启动失败"
        return 1
    fi
}

# 手动修复指导
show_manual_fix_guide() {
    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                    手动修复指导                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${WHITE}如果自动修复不起作用，请手动执行以下步骤：${NC}"
    echo
    echo -e "${YELLOW}步骤 1: 进入安装目录${NC}"
    echo "cd $INSTALL_DIR"
    echo
    echo -e "${YELLOW}步骤 2: 完全停止服务${NC}"
    echo "$COMPOSE_CMD down --volumes --remove-orphans"
    echo
    echo -e "${YELLOW}步骤 3: 清理残留容器${NC}"
    echo "docker ps -a --filter \"label=com.docker.compose.project=trilium\" --format \"{{.ID}}\" | xargs -r docker rm -f"
    echo
    echo -e "${YELLOW}步骤 4: 拉取最新镜像${NC}"
    echo "$COMPOSE_CMD pull"
    echo
    echo -e "${YELLOW}步骤 5: 强制重新创建${NC}"
    echo "$COMPOSE_CMD up -d --force-recreate"
    echo
    echo -e "${WHITE}如果问题仍然存在，请考虑：${NC}"
    echo "• 升级到 Docker Compose V2: apt install docker-compose-plugin"
    echo "• 检查磁盘空间是否充足"
    echo "• 查看详细错误日志: $COMPOSE_CMD logs"
    echo "• 重启 Docker 服务: systemctl restart docker"
    echo
    read -p "按回车键返回..."
}

# 服务管理函数
manage_service() {
    local action=$1
    cd "$INSTALL_DIR"
    
    case $action in
        "start")
            info "启动Trilium服务..."
            eval "$COMPOSE_CMD up -d"
            if [[ $? -eq 0 ]]; then
                success "服务启动成功！"
            else
                error "服务启动失败"
            fi
            ;;
        "stop")
            info "停止Trilium服务..."
            eval "$COMPOSE_CMD down"
            if [[ $? -eq 0 ]]; then
                success "服务停止成功！"
            else
                error "服务停止失败"
            fi
            ;;
        "restart")
            info "重启Trilium服务..."
            eval "$COMPOSE_CMD restart"
            if [[ $? -eq 0 ]]; then
                success "服务重启成功！"
            else
                error "服务重启失败"
            fi
            ;;
        "status")
            info "服务状态:"
            eval "$COMPOSE_CMD ps"
            ;;
        "logs")
            info "实时日志 (按Ctrl+C退出):"
            eval "$COMPOSE_CMD logs -f"
            ;;
        "update")
            update_trilium_with_fix
            ;;
        "backup")
            backup_data
            ;;
        "restore")
            restore_data
            ;;
    esac
    
    if [[ "$action" != "logs" ]]; then
        echo
        read -p "按回车键返回管理面板..."
        show_management_panel
    fi
}

# 备份数据函数
backup_data() {
    info "备份Trilium数据..."
    
    local backup_dir="/backup/trilium"
    local date=$(date +%Y%m%d_%H%M%S)
    local backup_file="trilium-backup-$date.tar.gz"
    
    mkdir -p "$backup_dir"
    
    if eval "$COMPOSE_CMD ps" | grep -q "trilium.*Up"; then
        eval "$COMPOSE_CMD exec trilium tar -czf \"/tmp/$backup_file\" -C /home/node/trilium-data ."
        docker cp $(eval "$COMPOSE_CMD ps -q trilium"):/tmp/$backup_file "$backup_dir/"
        eval "$COMPOSE_CMD exec trilium rm \"/tmp/$backup_file\""
        
        if [[ -f "$backup_dir/$backup_file" ]]; then
            success "备份完成: $backup_dir/$backup_file"
        else
            error "备份失败"
        fi
    else
        error "Trilium服务未运行，请先启动服务"
    fi
}

# 恢复数据函数  
restore_data() {
    info "数据恢复功能"
    echo
    
    local backup_dir="/backup/trilium"
    if [[ -d "$backup_dir" ]]; then
        echo "可用的备份文件:"
        ls -la "$backup_dir"/*.tar.gz 2>/dev/null || echo "未找到备份文件"
        echo
    fi
    
    read -p "请输入备份文件完整路径: " backup_file
    
    if [[ ! -f "$backup_file" ]]; then
        error "备份文件不存在: $backup_file"
        return 1
    fi
    
    echo
    echo -e "${RED}警告: 这将覆盖现有的所有数据！${NC}"
    read -p "确认继续? (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        info "开始恢复数据..."
        
        eval "$COMPOSE_CMD down"
        eval "$COMPOSE_CMD up -d trilium"
        sleep 5
        
        docker cp "$backup_file" $(eval "$COMPOSE_CMD ps -q trilium"):/tmp/restore.tar.gz
        eval "$COMPOSE_CMD exec trilium sh -c \"rm -rf /home/node/trilium-data/* && tar -xzf /tmp/restore.tar.gz -C /home/node/trilium-data\""
        eval "$COMPOSE_CMD exec trilium rm /tmp/restore.tar.gz"
        eval "$COMPOSE_CMD up -d"
        
        success "数据恢复完成！"
    else
        info "恢复操作已取消"
    fi
}

# 检查系统要求
check_requirements() {
    info "检查系统要求..."
    
    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        error "不支持的操作系统"
        exit 1
    fi
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        warning "Docker未安装，正在安装Docker..."
        install_docker
    else
        success "Docker已安装"
        # 检查Docker服务是否运行
        if ! systemctl is-active --quiet docker; then
            warning "Docker服务未运行，正在启动..."
            systemctl start docker
            systemctl enable docker
        fi
    fi
    
    # 检查Docker Compose (优先使用V2)
    check_docker_compose
}

# 检查并安装Docker Compose (优化版本，优先V2)
check_docker_compose() {
    local has_compose_plugin=false
    local has_compose_standalone=false
    
    # 检查Docker Compose插件 (V2 - 优先选择)
    if docker compose version &> /dev/null; then
        has_compose_plugin=true
        COMPOSE_CMD="docker compose"
        success "Docker Compose V2 插件已安装 (推荐)"
    fi
    
    # 检查独立的Docker Compose (V1)
    if command -v docker-compose &> /dev/null; then
        has_compose_standalone=true
        if [[ "$has_compose_plugin" == false ]]; then
            COMPOSE_CMD="docker-compose"
            warning "使用 Docker Compose V1 (建议升级到V2以避免已知bug)"
        fi
    fi
    
    # 如果都没有安装，优先安装V2
    if [[ "$has_compose_plugin" == false && "$has_compose_standalone" == false ]]; then
        warning "Docker Compose未安装，正在安装Docker Compose V2..."
        install_docker_compose_v2
    fi
    
    # 验证最终的命令
    if ! eval "$COMPOSE_CMD version" &> /dev/null; then
        error "Docker Compose安装验证失败"
        exit 1
    fi
    
    # 提醒用户升级V1到V2
    if [[ "$COMPOSE_CMD" == "docker-compose" ]]; then
        echo
        warning "您正在使用 Docker Compose V1，建议升级到 V2 以获得更好的稳定性"
        echo "升级方法: apt install docker-compose-plugin"
        read -p "现在升级到 V2 吗? (y/N): " upgrade_now
        if [[ "$upgrade_now" =~ ^[Yy]$ ]]; then
            install_docker_compose_v2
        fi
    fi
}

# 优先安装Docker Compose V2
install_docker_compose_v2() {
    info "安装Docker Compose V2..."
    
    # 通过包管理器安装V2插件
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y docker-compose-plugin
        if docker compose version &> /dev/null; then
            COMPOSE_CMD="docker compose"
            success "Docker Compose V2 安装成功"
            return 0
        fi
    elif command -v yum &> /dev/null; then
        yum install -y docker-compose-plugin
        if docker compose version &> /dev/null; then
            COMPOSE_CMD="docker compose"
            success "Docker Compose V2 安装成功"
            return 0
        fi
    fi
    
    # 备用方案：手动安装V2
    info "通过官方发布版本安装Docker Compose V2..."
    
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest 2>/dev/null | grep 'tag_name' | cut -d\" -f4)
    
    if [[ -z "$COMPOSE_VERSION" ]]; then
        warning "无法获取最新版本，使用固定版本"
        COMPOSE_VERSION="v2.21.0"
    fi
    
    mkdir -p ~/.docker/cli-plugins/
    curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" -o ~/.docker/cli-plugins/docker-compose 2>/dev/null
    chmod +x ~/.docker/cli-plugins/docker-compose
    
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
        success "Docker Compose V2 安装成功"
        return 0
    fi
    
    # 如果V2安装失败，回退到V1
    warning "Docker Compose V2 安装失败，回退到 V1"
    install_docker_compose_v1
}

# 安装Docker
install_docker() {
    info "安装Docker..."
    
    # 更新包列表
    apt-get update
    
    # 安装必要的包
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # 添加Docker官方GPG密钥
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # 添加Docker仓库
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 安装Docker Engine (包含V2插件)
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # 启动Docker服务
    systemctl start docker
    systemctl enable docker
    
    success "Docker安装完成"
}

# Docker Compose V1 安装 (备用方案)
install_docker_compose_v1() {
    info "安装Docker Compose V1 (备用方案)..."
    
    # 通过包管理器安装
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y docker-compose
        if command -v docker-compose &> /dev/null; then
            COMPOSE_CMD="docker-compose"
            success "Docker Compose V1 安装成功"
            return 0
        fi
    fi
    
    # 备用方案：直接下载安装
    info "通过官方发布版本安装Docker Compose V1..."
    
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    
    if [[ -z "$COMPOSE_VERSION" ]]; then
        warning "无法获取最新版本，使用固定版本"
        COMPOSE_VERSION="v2.21.0"
    fi
    
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    if command -v docker-compose &> /dev/null && docker-compose version &> /dev/null; then
        COMPOSE_CMD="docker-compose"
        success "Docker Compose V1 安装成功"
    else
        error "Docker Compose安装失败"
        exit 1
    fi
}

# 域名配置
configure_domain() {
    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                      域名配置                              ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    while true; do
        echo
        read -p "请输入您的域名 (例如: notes.example.com): " DOMAIN
        
        if [[ -z "$DOMAIN" ]]; then
            error "域名不能为空"
            continue
        fi
        
        echo
        echo -e "您输入的域名是: ${GREEN}$DOMAIN${NC}"
        read -p "确认吗? (y/n): " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            break
        fi
    done
    
    success "域名配置完成: $DOMAIN"
}

# SSL证书配置
configure_ssl() {
    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                     SSL证书配置                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    echo
    echo "请选择SSL证书类型:"
    echo -e "${WHITE}1)${NC} 不使用SSL (仅HTTP)"
    echo -e "${WHITE}2)${NC} 使用Let's Encrypt自动获取证书"
    echo -e "${WHITE}3)${NC} 使用Cloudflare证书 (手动上传)"
    echo
    
    while true; do
        read -p "请选择 (1-3): " ssl_choice
        
        case $ssl_choice in
            1)
                USE_SSL=false
                info "将使用HTTP模式部署"
                break
                ;;
            2)
                USE_SSL=true
                SSL_TYPE="letsencrypt"
                configure_letsencrypt
                break
                ;;
            3)
                USE_SSL=true
                SSL_TYPE="cloudflare"
                configure_cloudflare_cert
                break
                ;;
            *)
                error "无效选择，请输入1-3"
                ;;
        esac
    done
}

# Let's Encrypt配置
configure_letsencrypt() {
    echo
    info "配置Let's Encrypt证书..."
    
    while true; do
        read -p "请输入您的邮箱地址 (用于Let's Encrypt通知): " EMAIL
        
        if [[ -z "$EMAIL" ]]; then
            error "邮箱不能为空"
            continue
        fi
        
        break
    done
    
    success "Let's Encrypt配置完成"
}

# Cloudflare证书配置
configure_cloudflare_cert() {
    echo
    info "配置Cloudflare证书..."
    echo
    echo -e "${YELLOW}Cloudflare证书格式说明:${NC}"
    echo "• 证书文件 (.crt/.pem): 包含完整的证书链"
    echo "• 私钥文件 (.key): 对应的私钥文件"
    echo "• 从Cloudflare控制台 → SSL/TLS → Origin Certificates 获取"
    echo
    
    # 创建证书目录
    mkdir -p "$CONFIG_DIR/certs"
    
    # 配置证书文件
    while true; do
        echo
        read -p "请输入证书文件的完整路径 (.crt/.pem): " cert_file
        
        if [[ ! -f "$cert_file" ]]; then
            error "证书文件不存在: $cert_file"
            continue
        fi
        
        # 验证证书文件格式
        if ! openssl x509 -in "$cert_file" -text -noout &> /dev/null; then
            error "无效的证书文件格式"
            continue
        fi
        
        # 复制证书文件
        CF_CERT_PATH="$CONFIG_DIR/certs/cert.pem"
        cp "$cert_file" "$CF_CERT_PATH"
        success "证书文件复制完成"
        break
    done
    
    # 配置私钥文件
    while true; do
        echo
        read -p "请输入私钥文件的完整路径 (.key): " key_file
        
        if [[ ! -f "$key_file" ]]; then
            error "私钥文件不存在: $key_file"
            continue
        fi
        
        # 验证私钥文件格式
        if ! openssl rsa -in "$key_file" -check -noout &> /dev/null; then
            error "无效的私钥文件格式"
            continue
        fi
        
        # 复制私钥文件
        CF_KEY_PATH="$CONFIG_DIR/certs/key.pem"
        cp "$key_file" "$CF_KEY_PATH"
        success "私钥文件复制完成"
        break
    done
    
    # 设置文件权限
    chmod 600 "$CF_CERT_PATH" "$CF_KEY_PATH"
    
    success "Cloudflare证书配置完成"
}

# 端口配置
configure_ports() {
    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                      端口配置                              ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    # HTTP端口配置
    while true; do
        read -p "HTTP端口 (默认80): " input_http_port
        HTTP_PORT=${input_http_port:-80}
        
        if [[ "$HTTP_PORT" =~ ^[0-9]+$ ]] && [ "$HTTP_PORT" -ge 1 ] && [ "$HTTP_PORT" -le 65535 ]; then
            break
        else
            error "无效的端口号"
        fi
    done
    
    # HTTPS端口配置 (如果启用SSL)
    if [[ "$USE_SSL" == true ]]; then
        while true; do
            read -p "HTTPS端口 (默认443): " input_https_port
            HTTPS_PORT=${input_https_port:-443}
            
            if [[ "$HTTPS_PORT" =~ ^[0-9]+$ ]] && [ "$HTTPS_PORT" -ge 1 ] && [ "$HTTPS_PORT" -le 65535 ]; then
                if [[ "$HTTPS_PORT" == "$HTTP_PORT" ]]; then
                    error "HTTPS端口不能与HTTP端口相同"
                    continue
                fi
                break
            else
                error "无效的端口号"
            fi
        done
    fi
    
    success "端口配置完成"
}

# 管理员密码配置
configure_admin_password() {
    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                   管理员密码配置                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    echo
    info "为了安全起见，建议设置一个强密码 (至少8个字符，包含数字和字母)"
    
    while true; do
        read -s -p "请设置管理员密码: " ADMIN_PASSWORD
        echo
        
        if [[ ${#ADMIN_PASSWORD} -lt 8 ]]; then
            error "密码至少需要8个字符"
            continue
        fi
        
        read -s -p "请确认密码: " confirm_password
        echo
        
        if [[ "$ADMIN_PASSWORD" != "$confirm_password" ]]; then
            error "两次输入的密码不一致"
            continue
        fi
        
        break
    done
    
    success "管理员密码配置完成"
}

# 创建目录结构
create_directories() {
    info "创建目录结构..."
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$CONFIG_DIR/nginx"
    
    success "目录结构创建完成"
}

# 生成Nginx配置
generate_nginx_config() {
    info "生成Nginx配置..."
    
    if [[ "$USE_SSL" == false ]]; then
        # HTTP only配置
        cat > "$CONFIG_DIR/nginx/nginx.conf" << EOF
events {
    worker_connections 1024;
}

http {
    upstream trilium {
        server trilium:8080;
    }

    server {
        listen 80;
        server_name $DOMAIN;

        client_max_body_size 50M;

        location / {
            proxy_pass http://trilium;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
            proxy_read_timeout 86400;
        }
    }
}
EOF
    elif [[ "$SSL_TYPE" == "letsencrypt" ]]; then
        # Let's Encrypt配置
        cat > "$CONFIG_DIR/nginx/nginx.conf" << EOF
events {
    worker_connections 1024;
}

http {
    upstream trilium {
        server trilium:8080;
    }

    server {
        listen 80;
        server_name $DOMAIN;

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            return 301 https://\$host\$request_uri;
        }
    }

    server {
        listen 443 ssl http2;
        server_name $DOMAIN;

        ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;

        client_max_body_size 50M;

        location / {
            proxy_pass http://trilium;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_cache_bypass \$http_upgrade;
            proxy_read_timeout 86400;
        }
    }
}
EOF
    elif [[ "$SSL_TYPE" == "cloudflare" ]]; then
        # Cloudflare证书配置
        cat > "$CONFIG_DIR/nginx/nginx.conf" << EOF
events {
    worker_connections 1024;
}

http {
    upstream trilium {
        server trilium:8080;
    }

    server {
        listen 80;
        server_name $DOMAIN;
        return 301 https://\$host\$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name $DOMAIN;

        ssl_certificate /etc/nginx/certs/cert.pem;
        ssl_certificate_key /etc/nginx/certs/key.pem;

        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;

        client_max_body_size 50M;

        location / {
            proxy_pass http://trilium;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_cache_bypass \$http_upgrade;
            proxy_read_timeout 86400;
        }
    }
}
EOF
    fi
    
    success "Nginx配置生成完成"
}

# 生成Docker Compose配置 (移除version字段，避免警告)
generate_docker_compose() {
    info "生成Docker Compose配置..."
    
    if [[ "$USE_SSL" == false ]]; then
        # HTTP only配置
        cat > "$INSTALL_DIR/docker-compose.yml" << EOF
services:
  trilium:
    image: triliumnext/notes:${TRILIUM_VERSION}
    restart: unless-stopped
    environment:
      - TRILIUM_DATA_DIR=/home/node/trilium-data
    volumes:
      - ${DATA_DIR}:/home/node/trilium-data
    networks:
      - trilium-network

  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "${HTTP_PORT}:80"
    volumes:
      - ${CONFIG_DIR}/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - trilium
    networks:
      - trilium-network

networks:
  trilium-network:
    driver: bridge
EOF
    elif [[ "$SSL_TYPE" == "letsencrypt" ]]; then
        # Let's Encrypt配置
        cat > "$INSTALL_DIR/docker-compose.yml" << EOF
services:
  trilium:
    image: triliumnext/notes:${TRILIUM_VERSION}
    restart: unless-stopped
    environment:
      - TRILIUM_DATA_DIR=/home/node/trilium-data
    volumes:
      - ${DATA_DIR}:/home/node/trilium-data
    networks:
      - trilium-network

  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "${HTTP_PORT}:80"
      - "${HTTPS_PORT}:443"
    volumes:
      - ${CONFIG_DIR}/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    depends_on:
      - trilium
    networks:
      - trilium-network

  certbot:
    image: certbot/certbot
    restart: "no"
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait \$\${!}; done;'"

networks:
  trilium-network:
    driver: bridge
EOF
    elif [[ "$SSL_TYPE" == "cloudflare" ]]; then
        # Cloudflare证书配置
        cat > "$INSTALL_DIR/docker-compose.yml" << EOF
services:
  trilium:
    image: triliumnext/notes:${TRILIUM_VERSION}
    restart: unless-stopped
    environment:
      - TRILIUM_DATA_DIR=/home/node/trilium-data
    volumes:
      - ${DATA_DIR}:/home/node/trilium-data
    networks:
      - trilium-network

  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "${HTTP_PORT}:80"
      - "${HTTPS_PORT}:443"
    volumes:
      - ${CONFIG_DIR}/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ${CONFIG_DIR}/certs:/etc/nginx/certs:ro
    depends_on:
      - trilium
    networks:
      - trilium-network

networks:
  trilium-network:
    driver: bridge
EOF
    fi
    
    success "Docker Compose配置生成完成"
}

# 配置防火墙
configure_firewall() {
    info "配置防火墙..."
    
    if command -v ufw &> /dev/null; then
        ufw allow $HTTP_PORT/tcp
        if [[ "$USE_SSL" == true ]]; then
            ufw allow $HTTPS_PORT/tcp
        fi
        success "UFW防火墙规则已添加"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=$HTTP_PORT/tcp
        if [[ "$USE_SSL" == true ]]; then
            firewall-cmd --permanent --add-port=$HTTPS_PORT/tcp
        fi
        firewall-cmd --reload
        success "firewalld防火墙规则已添加"
    else
        warning "未检测到防火墙，请手动开放端口 $HTTP_PORT"
        if [[ "$USE_SSL" == true ]]; then
            warning "请手动开放HTTPS端口 $HTTPS_PORT"
        fi
    fi
}

# Let's Encrypt证书获取
obtain_letsencrypt_cert() {
    if [[ "$SSL_TYPE" != "letsencrypt" ]]; then
        return
    fi
    
    info "获取Let's Encrypt证书..."
    
    # 创建certbot目录
    mkdir -p "$INSTALL_DIR/certbot/conf"
    mkdir -p "$INSTALL_DIR/certbot/www"
    
    # 先启动HTTP服务以验证域名
    cd "$INSTALL_DIR"
    eval "$COMPOSE_CMD up -d nginx"
    
    sleep 5
    
    # 获取证书
    eval "$COMPOSE_CMD run --rm certbot \
        certbot certonly --webroot -w /var/www/certbot \
        --email $EMAIL \
        --agree-tos \
        --no-eff-email \
        -d $DOMAIN"
    
    if [[ $? -eq 0 ]]; then
        success "Let's Encrypt证书获取成功"
        
        # 重新启动服务以启用HTTPS
        eval "$COMPOSE_CMD down"
        eval "$COMPOSE_CMD up -d"
    else
        error "Let's Encrypt证书获取失败"
        exit 1
    fi
}

# 启动服务
start_services() {
    info "启动Trilium服务..."
    
    cd "$INSTALL_DIR"
    
    if [[ "$SSL_TYPE" == "letsencrypt" ]]; then
        obtain_letsencrypt_cert
    else
        eval "$COMPOSE_CMD up -d"
    fi
    
    # 等待服务启动
    info "等待服务启动..."
    sleep 10
    
    # 检查服务状态
    if eval "$COMPOSE_CMD ps" | grep -q "Up"; then
        success "Trilium服务启动成功!"
    else
        error "Trilium服务启动失败"
        eval "$COMPOSE_CMD logs"
        exit 1
    fi
}

# 显示安装结果
show_result() {
    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${WHITE}                            安装完成!                                    ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    if [[ "$USE_SSL" == true ]]; then
        echo -e "${WHITE}访问地址:${NC} ${GREEN}https://$DOMAIN${NC}"
        if [[ "$HTTPS_PORT" != "443" ]]; then
            echo -e "${WHITE}带端口:${NC} ${GREEN}https://$DOMAIN:$HTTPS_PORT${NC}"
        fi
    else
        echo -e "${WHITE}访问地址:${NC} ${GREEN}http://$DOMAIN${NC}"
        if [[ "$HTTP_PORT" != "80" ]]; then
            echo -e "${WHITE}带端口:${NC} ${GREEN}http://$DOMAIN:$HTTP_PORT${NC}"
        fi
    fi
    
    echo
    echo -e "${WHITE}管理命令:${NC}"
    echo -e "  启动服务: ${CYAN}cd $INSTALL_DIR && $COMPOSE_CMD up -d${NC}"
    echo -e "  停止服务: ${CYAN}cd $INSTALL_DIR && $COMPOSE_CMD down${NC}"
    echo -e "  查看日志: ${CYAN}cd $INSTALL_DIR && $COMPOSE_CMD logs -f${NC}"
    echo -e "  重启服务: ${CYAN}cd $INSTALL_DIR && $COMPOSE_CMD restart${NC}"
    echo -e "  智能管理: ${CYAN}trilium${NC}"
    
    echo
    echo -e "${WHITE}数据目录:${NC} ${CYAN}$DATA_DIR${NC}"
    echo -e "${WHITE}配置目录:${NC} ${CYAN}$CONFIG_DIR${NC}"
    
    if [[ "$SSL_TYPE" == "letsencrypt" ]]; then
        echo
        echo -e "${YELLOW}注意:${NC} Let's Encrypt证书会自动续期"
    fi
    
    echo
    echo -e "${WHITE}首次访问时请完成初始化设置:${NC}"
    echo -e "1. 设置管理员密码"
    echo -e "2. 配置数据加密 (推荐)"
    echo -e "3. 完成安装向导"
    
    echo
    success "Trilium Notes已成功部署!"
}

# 创建管理脚本 (支持智能修复)
create_management_script() {
    info "创建管理脚本..."
    
    cat > "$INSTALL_DIR/trilium-manage.sh" << 'EOF'
#!/bin/bash

# Trilium Docker 智能管理脚本
INSTALL_DIR="/opt/trilium"
cd "$INSTALL_DIR"

# 检测可用的compose命令
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo "错误: 未找到docker-compose或docker compose命令"
    exit 1
fi

# 智能修复函数
smart_fix() {
    echo "开始智能修复..."
    
    # 停止并删除容器
    echo "停止并删除现有容器..."
    eval "$COMPOSE_CMD down --volumes --remove-orphans" 2>/dev/null || true
    
    # 清理残留容器
    echo "清理残留容器..."
    docker ps -a --filter "label=com.docker.compose.project=trilium" --format "{{.ID}}" 2>/dev/null | xargs -r docker rm -f 2>/dev/null || true
    
    # 重新创建
    echo "重新创建并启动服务..."
    eval "$COMPOSE_CMD up -d --force-recreate"
    
    if [[ $? -eq 0 ]]; then
        echo "修复完成!"
    else
        echo "修复失败，请检查日志"
        eval "$COMPOSE_CMD logs"
    fi
}

case "$1" in
    start)
        echo "启动Trilium服务..."
        eval "$COMPOSE_CMD up -d"
        ;;
    stop)
        echo "停止Trilium服务..."
        eval "$COMPOSE_CMD down"
        ;;
    restart)
        echo "重启Trilium服务..."
        eval "$COMPOSE_CMD restart"
        ;;
    logs)
        echo "查看Trilium日志..."
        eval "$COMPOSE_CMD logs -f"
        ;;
    status)
        echo "查看服务状态..."
        eval "$COMPOSE_CMD ps"
        ;;
    update)
        echo "更新Trilium..."
        eval "$COMPOSE_CMD pull"
        if eval "$COMPOSE_CMD up -d"; then
            echo "更新成功!"
        else
            echo "更新失败，尝试智能修复..."
            smart_fix
        fi
        ;;
    fix)
        smart_fix
        ;;
    backup)
        echo "备份Trilium数据..."
        BACKUP_DIR="/backup/trilium"
        DATE=$(date +%Y%m%d_%H%M%S)
        
        mkdir -p "$BACKUP_DIR"
        eval "$COMPOSE_CMD exec trilium tar -czf \"/tmp/trilium-backup-$DATE.tar.gz\" -C /home/node/trilium-data ."
        docker cp $(eval "$COMPOSE_CMD ps -q trilium"):/tmp/trilium-backup-$DATE.tar.gz "$BACKUP_DIR/"
        eval "$COMPOSE_CMD exec trilium rm \"/tmp/trilium-backup-$DATE.tar.gz\""
        
        echo "备份完成: $BACKUP_DIR/trilium-backup-$DATE.tar.gz"
        ;;
    restore)
        if [ -z "$2" ]; then
            echo "使用方法: $0 restore <备份文件路径>"
            exit 1
        fi
        
        if [ ! -f "$2" ]; then
            echo "备份文件不存在: $2"
            exit 1
        fi
        
        echo "恢复Trilium数据..."
        echo "警告: 这将覆盖现有数据!"
        read -p "确认继续? (y/N): " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            eval "$COMPOSE_CMD down"
            eval "$COMPOSE_CMD up -d trilium"
            sleep 5
            docker cp "$2" $(eval "$COMPOSE_CMD ps -q trilium"):/tmp/restore.tar.gz
            eval "$COMPOSE_CMD exec trilium sh -c \"rm -rf /home/node/trilium-data/* && tar -xzf /tmp/restore.tar.gz -C /home/node/trilium-data\""
            eval "$COMPOSE_CMD exec trilium rm /tmp/restore.tar.gz"
            eval "$COMPOSE_CMD up -d"
            echo "数据恢复完成"
        else
            echo "恢复已取消"
        fi
        ;;
    *)
        echo "Trilium Docker 智能管理脚本 - 优化版"
        echo
        echo "使用方法: $0 {start|stop|restart|logs|status|update|fix|backup|restore}"
        echo
        echo "命令说明:"
        echo "  start   - 启动服务"
        echo "  stop    - 停止服务" 
        echo "  restart - 重启服务"
        echo "  logs    - 查看日志"
        echo "  status  - 查看状态"
        echo "  update  - 智能更新到最新版本"
        echo "  fix     - 智能修复 ContainerConfig 等错误"
        echo "  backup  - 备份数据"
        echo "  restore - 恢复数据"
        echo
        echo "智能功能:"
        echo "• 自动检测 Docker Compose 版本"
        echo "• 更新失败时自动尝试修复"
        echo "• 支持强制重新创建容器"
        echo
        exit 1
        ;;
esac
EOF

    chmod +x "$INSTALL_DIR/trilium-manage.sh"
    
    # 创建系统级别的命令链接
    ln -sf "$INSTALL_DIR/trilium-manage.sh" /usr/local/bin/trilium
    
    success "智能管理脚本创建完成"
    info "现在可以使用 'trilium' 命令进行管理"
}

# 主安装流程
main() {
    show_banner
    
    # 检查是否已安装
    if check_existing_installation; then
        # 智能检测compose命令
        if docker compose version &> /dev/null; then
            COMPOSE_CMD="docker compose"
        elif command -v docker-compose &> /dev/null; then
            COMPOSE_CMD="docker-compose"
        else
            error "未找到docker-compose命令"
            exit 1
        fi
        
        # 显示管理面板
        if ! show_management_panel; then
            # 用户选择重新安装，继续执行安装流程
            info "开始重新配置..."
        else
            exit 0
        fi
    fi
    
    # 检查环境
    check_root
    check_requirements
    
    echo
    read -p "系统检查完成，按回车键继续安装..."
    
    # 交互式配置
    configure_domain
    configure_ssl
    configure_ports
    configure_admin_password
    
    # 创建安装环境
    create_directories
    generate_nginx_config
    generate_docker_compose
    create_management_script
    
    # 配置系统
    configure_firewall
    
    # 启动服务
    start_services
    
    # 显示结果
    show_result
    
    # 安装完成后显示管理面板
    echo
    read -p "按回车键进入管理面板..."
    show_management_panel
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
