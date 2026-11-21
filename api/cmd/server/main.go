package main

import (
	"context"
	"log"
	"net/http"
	"time"

	"bloodline/internal/auth"
	"bloodline/internal/config"
	"bloodline/internal/events"
	"bloodline/internal/httpapi"
	"bloodline/internal/nexconn"
	"bloodline/internal/notify"
	"bloodline/internal/ranks"
	"bloodline/internal/reminders"
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

	chat, err := newChatClient(cfg)
	if err != nil {
		return err
	}

	issuer, err := auth.NewIssuer(cfg.JWTSecret, jwtTTL)
	if err != nil {
		return err
	}

	bus := events.New()
	notifier := notify.New(st)
	bus.Subscribe(events.RequestCreated, notifier.Handle)
	bus.Subscribe(events.RequestAccepted, notifier.Handle)
	bus.Subscribe(events.RequestFulfilled, notifier.Handle)
	if cfgHasFeature(cfg.Features, "ranks") {
		bus.Subscribe(events.DonationRecorded, ranks.New(st).Handle)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	reminderRunner := reminders.New(st)
	if cfgHasFeature(cfg.Features, "reminders") {
		bus.Subscribe(events.RequestCreated, reminderRunner.Handle)
		go reminderRunner.RunTicker(ctx, time.Hour)
	}

	svc := service.New(st, chat, issuer,
		service.WithDemoOTP(cfg.DemoOTP),
		service.WithFeatures(cfg.Features),
		service.WithMatchRadius(cfg.MatchRadiusKM),
		service.WithBus(bus),
	)
	opts := append(devRoutes(cfg.Dev), httpapi.WithReminderRunner(reminderRunner))
	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           httpapi.New(svc, issuer, opts...),
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("BloodLine API listening on :%s (db %s)", cfg.Port, cfg.DBPath)
	return srv.ListenAndServe()
}

// devRoutes exposes dev-only HTTP endpoints only when DEV=1.
func devRoutes(enabled bool) []httpapi.ServerOption {
	if !enabled {
		return nil
	}
	return []httpapi.ServerOption{httpapi.WithDevRoutes()}
}

// newChatClient selects the Nexconn implementation. Real mode is the default;
// offline modes never call the network. Fake (in-memory, stateful) takes
// precedence over the legacy no-op mock when both flags are set.
func newChatClient(cfg config.Config) (nexconn.Client, error) {
	switch {
	case cfg.NexconnFake:
		return nexconn.NewFakeClient(), nil
	case cfg.NexconnMock:
		return nexconn.NoopClient{}, nil
	default:
		return nexconn.New(
			cfg.NexconnAppKey,
			cfg.NexconnAppSecret,
			cfg.NexconnAPIBase,
			cfg.NexconnAPIBaseBackup,
		)
	}
}

func cfgHasFeature(features []string, name string) bool {
	for _, f := range features {
		if f == name {
			return true
		}
	}
	return false
}
