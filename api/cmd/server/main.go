package main

import (
	"log"
	"net/http"
	"time"

	"bloodline/internal/config"
	"bloodline/internal/httpapi"
	"bloodline/internal/store"
)

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

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           httpapi.New(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("BloodLine API listening on :%s (db %s)", cfg.Port, cfg.DBPath)
	return srv.ListenAndServe()
}
