#!/bin/bash

#  Cursor2API启动脚本

set -e
export GOTOOLCHAIN=go1.26.10

# 定义颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 打印标题
print_header() {
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${WHITE}    🚀  Cursor2API启动器${NC}"
    echo -e "${CYAN}=========================================${NC}"
}

# 检查Go环境
check_go() {
    if ! command -v go &> /dev/null; then
        echo -e "${RED}❌ Go 未安装，请先安装 Go 1.26.10 或已修复的更新版本${NC}"
        echo -e "${YELLOW}💡 安装方法: https://golang.org/dl/${NC}"
        exit 1
    fi

    GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    REQUIRED_VERSION="1.26.10"

    if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$GO_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
        echo -e "${RED}❌ Go 版本 $GO_VERSION 过低，请安装 Go $REQUIRED_VERSION 或更高版本${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ Go 版本检查通过: $GO_VERSION${NC}"
}

# 检查Node.js环境
check_nodejs() {
    if ! command -v node &> /dev/null; then
        echo -e "${RED}❌ Node.js 未安装，请先安装 Node.js 22.23.4 / 24.22.1 / 26.12.1 或相应安全补丁${NC}"
        echo -e "${YELLOW}💡 安装方法: https://nodejs.org/${NC}"
        exit 1
    fi

    NODE_VERSION=$(node --version | sed 's/v//')
    node "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/check-node.cjs"

    echo -e "${GREEN}✅ Node.js 版本检查通过: $NODE_VERSION${NC}"
}

# 处理环境配置
setup_env() {
    if [ ! -f .env ]; then
        echo -e "${YELLOW}📝 创建默认 .env 配置文件...${NC}"
        cat > .env << EOF
# 服务器配置
PORT=8002
DEBUG=false

# API配置
API_KEY=0000
MODELS=claude-sonnet-4.6
SYSTEM_PROMPT_INJECT=

# 请求配置
TIMEOUT=30
USER_AGENT=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36

# Cursor配置
SCRIPT_URL=https://cursor.com/149e9513-01fa-4fb0-aad4-566afd725d1b/2d206a39-8ed7-437e-a3be-862e0f06eea3/a-4-a/c.js?i=0&v=3&h=cursor.com
EOF
        echo -e "${GREEN}✅ 默认 .env 文件已创建${NC}"
    else
        echo -e "${GREEN}✅ 配置文件 .env 已存在${NC}"
    fi
}

# 构建应用
build_app() {
    echo -e "${BLUE}📦 正在下载 Go 依赖...${NC}"
    GOTOOLCHAIN=go1.26.10 go mod download

    echo -e "${BLUE}🔨 正在编译 Go 应用...${NC}"
    GOTOOLCHAIN=go1.26.10 go build -o cursor2api-go .

    if [ ! -f cursor2api-go ]; then
        echo -e "${RED}❌ 编译失败！${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ 应用编译成功！${NC}"
}

# 显示服务信息
show_info() {
    # 读取 .env 中的关键配置
    local port=8002
    local api_key="0000"
    local models="claude-sonnet-4.6"
    local debug="false"

    if [ -f .env ]; then
        _val=$(grep "^PORT=" .env | cut -d'=' -f2 || true); [ -n "$_val" ] && port=$_val
        _val=$(grep "^API_KEY=" .env | cut -d'=' -f2 || true); [ -n "$_val" ] && api_key=$_val
        _val=$(grep "^MODELS=" .env | cut -d'=' -f2 || true); [ -n "$_val" ] && models=$_val
        _val=$(grep "^DEBUG=" .env | cut -d'=' -f2 || true); [ -n "$_val" ] && debug=$_val
    fi

    # 掩码 API Key，只显示前4位
    local masked_key
    if [ ${#api_key} -le 4 ]; then
        masked_key="****"
    else
        masked_key="${api_key:0:4}****"
    fi

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  🌐 服务地址:  ${GREEN}http://localhost:${port}${NC}"
    echo -e "${WHITE}  📚 API 文档:  ${GREEN}http://localhost:${port}/${NC}"
    echo -e "${WHITE}  💊 健康检查:  ${GREEN}http://localhost:${port}/health${NC}"
    echo -e "${WHITE}  🔑 API 密钥:  ${YELLOW}${masked_key}${NC}"
    echo -e "${WHITE}  🤖 模型列表:  ${PURPLE}${models}${NC}"
    if [ "$debug" = "true" ]; then
        echo -e "${WHITE}  🐛 调试模式:  ${YELLOW}已启用${NC}"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}✅ 准备就绪，正在启动服务... 按 Ctrl+C 停止${NC}"
    echo ""
}

# 启动服务器
start_server() {
    # 捕获中断信号
    trap 'echo -e "\n${YELLOW}⏹️  正在停止服务器...${NC}"; exit 0' INT

    ./cursor2api-go
}

# 检查端口占用并在需要时清理
check_port() {
    # 如果 .env 存在，从中获取端口号，否则使用默认值 8002
    PORT_TO_CHECK=8002
    if [ -f .env ]; then
        ENV_PORT=$(grep "^PORT=" .env | cut -d '=' -f2 || true)
        if [ ! -z "$ENV_PORT" ]; then
            PORT_TO_CHECK=$ENV_PORT
        fi
    fi

    # 检查是否有进程占用该端口
    if command -v lsof &> /dev/null; then
        PID=$(lsof -t -i :$PORT_TO_CHECK || true)
        if [ ! -z "$PID" ]; then
            echo -e "${YELLOW}⚠️  检测到端口 $PORT_TO_CHECK 已被占用 (PID: $PID)，正在清理...${NC}"
            kill -9 $PID &> /dev/null || true
            sleep 1
            echo -e "${GREEN}✅ 端口 $PORT_TO_CHECK 已清理${NC}"
        fi
    fi
}

# 主函数
main() {
    print_header
    check_go
    check_nodejs
    setup_env
    check_port
    build_app
    show_info
    start_server
}

# 运行主函数
main