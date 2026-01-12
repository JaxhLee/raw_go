#!/bin/bash

# 构建 certimate_webhook 二进制文件
# release 版本
# Linux 平台 amd64 架构
# 输出文件名为 certimate_webhook_linux_amd64
# 输出文件路径为 ./bin/certimate_webhook_linux_amd64

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GOFLAGS="-trimpath -mod=readonly -buildvcs=false" go build -tags "netgo,osusergo,release" -ldflags "-s -w" -o certimate_webhook_linux_amd64 main.go
