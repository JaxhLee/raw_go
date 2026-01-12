package main

import (
	"context"
	"encoding/json"
	"flag"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
)

// This is the main package for the certimate webhook
// 使用 go-chi 作为 web 框架
// 接收 certimate 的 webhook 请求
// /webhook 路径接收 certimate 的 webhook 请求

type AppConfig struct {
	Port          string
	WebhookURL    string
	WebhookSecret string
	StoragePath   string
}

var appConfig AppConfig

func main() {
	// 通过 flag 读取配置
	port := flag.String("port", "8080", "port to listen on")
	webhookURL := flag.String("webhook-url", "/webhook", "webhook url")
	webhookSecret := flag.String("webhook-secret", "", "webhook secret")
	storagePath := flag.String("storage-path", "./ssl", "storage path")
	flag.Parse()

	appConfig = AppConfig{
		Port:          *port,
		WebhookURL:    *webhookURL,
		WebhookSecret: *webhookSecret,
		StoragePath:   *storagePath,
	}

	// 创建一个 chi 路由
	router := chi.NewRouter()

	// 注册 webhook 路由
	router.Post(appConfig.WebhookURL, handleWebhook)

	// 启动服务器，支持优雅关闭
	server := &http.Server{
		Addr:    ":" + appConfig.Port,
		Handler: router,
	}
	go func() {
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %s\n", err)
		}
	}()

	// 等待信号
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// 优雅关闭
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("shutdown: %s\n", err)
	}
	log.Println("shutdown complete")
}

type WebhookRequest struct {
	Token           string `json:"token"`
	Name            string `json:"name"`
	SubjectAltNames string `json:"subject_alt_names"`
	PemCert         string `json:"pem_cert"`
	PemPrivateKey   string `json:"pem_private_key"`
}

func handleWebhook(w http.ResponseWriter, r *http.Request) {
	// 获取请求体
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	var webhookRequest WebhookRequest
	err = json.Unmarshal(body, &webhookRequest)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// 验证 token
	if appConfig.WebhookSecret != "" && webhookRequest.Token != appConfig.WebhookSecret {
		http.Error(w, "Invalid token", http.StatusUnauthorized)
		return
	}

	// 保存证书
	certPath := filepath.Join(appConfig.StoragePath, webhookRequest.Name+".crt")
	err = os.WriteFile(certPath, []byte(webhookRequest.PemCert), 0644)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// 保存私钥
	privateKeyPath := filepath.Join(appConfig.StoragePath, webhookRequest.Name+".key")
	err = os.WriteFile(privateKeyPath, []byte(webhookRequest.PemPrivateKey), 0644)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// 返回成功
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("success"))
}
