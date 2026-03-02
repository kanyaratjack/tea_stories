package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"tea-store/backend-go/internal/config"
	api "tea-store/backend-go/internal/http"
	"tea-store/backend-go/internal/repo"
	"tea-store/backend-go/internal/service"
)

func main() {
	cfg := config.Load()

	ctx := context.Background()
	store, err := repo.NewPostgresStore(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("connect postgres failed: %v", err)
	}
	defer store.Close()
	svc := service.NewPOSService(store)
	h := api.NewHandler(svc)

	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      h.Router(),
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Printf("backend-go listening on http://localhost:%s", cfg.Port)
		log.Printf("postgres connected: %s", cfg.DatabaseURL)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server failed: %v", err)
		}
	}()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("graceful shutdown failed: %v", err)
	}
}
