package main

import (
	"testing"

	"bloodline/internal/config"
	"bloodline/internal/nexconn"
)

func TestDevRoutesOnlyWhenEnabled(t *testing.T) {
	if got := devRoutes(false); len(got) != 0 {
		t.Errorf("devRoutes(false) has %d options, want 0", len(got))
	}
	if got := devRoutes(true); len(got) != 1 {
		t.Errorf("devRoutes(true) has %d options, want 1", len(got))
	}
}

func TestNewChatClientSelectsMode(t *testing.T) {
	tests := []struct {
		name    string
		cfg     config.Config
		want    string
		wantErr bool
	}{
		{
			name: "fake wins over legacy mock and needs no credentials",
			cfg:  config.Config{NexconnFake: true, NexconnMock: true},
			want: "fake",
		},
		{
			name: "legacy mock",
			cfg:  config.Config{NexconnMock: true},
			want: "mock",
		},
		{
			name: "real is the default",
			cfg: config.Config{
				NexconnAppKey:        "key",
				NexconnAppSecret:     "secret",
				NexconnAPIBase:       "https://api.example.test",
				NexconnAPIBaseBackup: "https://api-b.example.test",
			},
			want: "real",
		},
		{
			name:    "real mode rejects missing credentials",
			cfg:     config.Config{},
			wantErr: true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			client, err := newChatClient(tt.cfg)
			if tt.wantErr {
				if err == nil {
					t.Fatal("newChatClient succeeded, want error")
				}
				return
			}
			if err != nil {
				t.Fatalf("newChatClient: %v", err)
			}
			var got string
			switch client.(type) {
			case *nexconn.FakeClient:
				got = "fake"
			case nexconn.NoopClient:
				got = "mock"
			case *nexconn.SDKClient:
				got = "real"
			}
			if got != tt.want {
				t.Errorf("client = %T (%s), want %s", client, got, tt.want)
			}
		})
	}
}
