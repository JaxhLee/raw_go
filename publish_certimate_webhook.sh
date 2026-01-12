#!/bin/bash

# --- 配置区域 ---
VERSION=$1                   # 想要发布的版本号
if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

RELEASE_DIR="./release_dist"       # 临时存放构建产物的目录
INCLUDE_SCRIPT="./certimate_webhook/install_certimate_webhook.sh"   # 想要一同发布的脚本
INCLUDE_CONFIG="./certimate_webhook/certimate_webhook_config.template.yaml"   # 想要一同发布的配置文件

# --- 1. 环境准备 ---
echo "🚀 开始发布流程: $VERSION"
mkdir -p $RELEASE_DIR

# --- 2. 交叉编译 (Go Build) ---
cd certimate_webhook

APP_NAME="certimate_webhook_linux_amd64"           # 你的程序名称
MAIN_PATH="./main.go"              # main.go 的路径

echo "📦 正在编译 Linux amd64 版本..."
# CGO_ENABLED=0 确保静态链接，适合所有 Linux 发行版
# -ldflags="-s -w" 减小体积 (Release 必备)
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
go build -tags "netgo,osusergo,release" -trimpath -ldflags="-s -w" -o "../$RELEASE_DIR/$APP_NAME" $MAIN_PATH
cd ..

if [ $? -ne 0 ]; then
    echo "❌ 编译失败，请检查 Go 代码。"
    exit 1
fi

# --- 3. 准备相关脚本 ---
if [ -f "$INCLUDE_SCRIPT" ]; then
    cp "$INCLUDE_SCRIPT" "$RELEASE_DIR/"
    echo "📄 已复制脚本: $INCLUDE_SCRIPT"
else
    echo "⚠️ 未找到脚本 $INCLUDE_SCRIPT，将只发布二进制文件。"
fi

if [ -f "$INCLUDE_CONFIG" ]; then
    cp "$INCLUDE_CONFIG" "$RELEASE_DIR/"
    echo "📄 已复制配置文件: $INCLUDE_CONFIG"
else
    echo "⚠️ 未找到配置文件 $INCLUDE_CONFIG，将只发布二进制文件。"
fi

# --- 4. 生成校验和 (可选但推荐) ---
echo "🔐 生成 SHA256 校验和..."
cd $RELEASE_DIR
sha256sum * > checksums.txt
cd ..

# --- 5. 使用 GitHub CLI 发布 ---
echo "☁️ 正在上传到 GitHub Release..."

# 尝试推送标签到远程，防止本地有标签但远程没有
git push origin "$VERSION" 2>/dev/null

# 检查 Release 是否已经存在
if gh release view "$VERSION" >/dev/null 2>&1; then
    echo "ℹ️ Release $VERSION 已存在，正在更新文件..."
    gh release upload "$VERSION" $RELEASE_DIR/* --clobber
else
    echo "🆕 正在创建新 Release $VERSION..."
    # 使用 --target 指定分支，gh 会自动处理标签
    gh release create "$VERSION" $RELEASE_DIR/* \
        --target "$(git branch --show-current)" \
        --title "Release $VERSION" \
        --notes "自动构建发布于 $(date '+%Y-%m-%d %H:%M:%S')"
fi

if [ $? -eq 0 ]; then
    echo "✅ 发布成功！"
    echo "🔗 查看地址: $(gh view --web --release $VERSION 2>/dev/null || echo '请前往 GitHub 网页查看')"
else
    echo "❌ 发布失败，请检查网络或 gh 登录状态。"
fi

# --- 6. 清理 ---
rm -rf $RELEASE_DIR  # 如果你想保留本地副本，可以注释掉这一行