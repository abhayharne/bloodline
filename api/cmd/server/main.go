package main

import (
	"log"
	"net/http"
	"time"

	"bloodline/internal/auth"
	"bloodline/internal/config"
	"bloodline/internal/httpapi"
	"bloodline/internal/nexconn"
	"bloodline/internal/service"
	"bloodline/internal/store"
)

const jwtTTL = 7 * 24 * time.Hour

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}

func run() error {
	if err := config.LoadDotEnv(); err != nil {
		return err
	}
	cfg, err := config.Load()
	if err != nil {
		return err
	}

	st, err := store.Open(cfg.DBPath)
	if err != nil {
		return err
	}
	defer st.Close()

	chat, err := nexconn.New(
		cfg.NexconnAppKey,
		cfg.NexconnAppSecret,
		cfg.NexconnAPIBase,
		cfg.NexconnAPIBaseBackup,
	)
	if err != nil {
		return err
	}

	issuer, err := auth.NewIssuer(cfg.JWTSecret, jwtTTL)
	if err != nil {
		return err
	}

	svc := service.New(st, chat, issuer,
		service.WithDemoOTP(cfg.DemoOTP),
		service.WithFeatures(cfg.Features),
	)
	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           httpapi.New(svc, issuer),
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("BloodLine API listening on :%s (db %s)", cfg.Port, cfg.DBPath)
	return srv.ListenAndServe()
}
