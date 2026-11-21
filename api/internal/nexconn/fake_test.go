package nexconn

import (
	"context"
	"reflect"
	"strings"
	"sync"
	"testing"
)

func TestFakeClientRoomLifecycle(t *testing.T) {
	f := NewFakeClient()
	ctx := context.Background()

	token, err := f.IssueToken(ctx, "u1", "Asha")
	if err != nil {
		t.Fatalf("IssueToken: %v", err)
	}
	if token != "fake-chat-token-u1" {
		t.Errorf("token = %q, want fake-chat-token-u1", token)
	}

	if err := f.CreateGroupChannel(ctx, "reqr1", "Blood request O+", "u1", []string{"b1", "d1"}); err != nil {
		t.Fatalf("CreateGroupChannel: %v", err)
	}
	room, ok := f.Channel("reqr1")
	if !ok {
		t.Fatal("channel not found after create")
	}
	if room.Owner != "u1" || room.Name != "Blood request O+" || room.Frozen {
		t.Errorf("unexpected room snapshot: %+v", room)
	}
	if want := []string{"b1", "d1", "u1"}; !reflect.DeepEqual(room.Members, want) {
		t.Errorf("members = %v, want %v", room.Members, want)
	}

	if err := f.JoinGroupChannel(ctx, "reqr1", []string{"d2", "d1"}); err != nil {
		t.Fatalf("JoinGroupChannel: %v", err)
	}
	room, _ = f.Channel("reqr1")
	if want := []string{"b1", "d1", "d2", "u1"}; !reflect.DeepEqual(room.Members, want) {
		t.Errorf("members after join = %v, want %v", room.Members, want)
	}

	if err := f.SendGroupMessage(ctx, "reqr1", "u1", "", "thanks"); err != nil {
		t.Fatalf("SendGroupMessage: %v", err)
	}
	room, _ = f.Channel("reqr1")
	if len(room.Messages) != 1 || room.Messages[0].Type != "RC:TxtMsg" ||
		room.Messages[0].FromUserID != "u1" || room.Messages[0].Content != "thanks" {
		t.Errorf("messages = %+v, want one default-type message", room.Messages)
	}

	if err := f.FreezeGroupChannel(ctx, "reqr1"); err != nil {
		t.Fatalf("FreezeGroupChannel: %v", err)
	}
	if err := f.FreezeGroupChannel(ctx, "reqr1"); err != nil {
		t.Fatalf("FreezeGroupChannel again: %v", err)
	}
	room, _ = f.Channel("reqr1")
	if !room.Frozen {
		t.Error("room not frozen")
	}
	if err := f.SendGroupMessage(ctx, "reqr1", "u1", "", "too late"); err == nil {
		t.Error("SendGroupMessage succeeded on a frozen room")
	}

	// A snapshot must not let callers mutate the client's state.
	room.Members[0] = "tampered"
	room.Messages[0].Content = "tampered"
	room, _ = f.Channel("reqr1")
	if room.Members[0] == "tampered" || room.Messages[0].Content == "tampered" {
		t.Error("Channel snapshot aliases internal state")
	}
}

func TestFakeClientRejectsInvalidCalls(t *testing.T) {
	setup := func() *FakeClient {
		f := NewFakeClient()
		if err := f.CreateGroupChannel(context.Background(), "reqr1", "room", "u1", nil); err != nil {
			t.Fatalf("CreateGroupChannel setup: %v", err)
		}
		return f
	}
	canceled, cancel := context.WithCancel(context.Background())
	cancel()
	tooMany := make([]string, maxJoinMembers+1)
	for i := range tooMany {
		tooMany[i] = "u"
	}

	tests := []struct {
		name string
		call func(*FakeClient) error
		want string
	}{
		{"token missing name", func(f *FakeClient) error {
			_, err := f.IssueToken(context.Background(), "u1", "")
			return err
		}, "required"},
		{"token canceled context", func(f *FakeClient) error {
			_, err := f.IssueToken(canceled, "u1", "Asha")
			return err
		}, context.Canceled.Error()},
		{"create duplicate", func(f *FakeClient) error {
			return f.CreateGroupChannel(context.Background(), "reqr1", "room", "u1", nil)
		}, "already exists"},
		{"create too many members", func(f *FakeClient) error {
			return f.CreateGroupChannel(context.Background(), "reqr2", "room", "u1", tooMany)
		}, "at most"},
		{"create empty member", func(f *FakeClient) error {
			return f.CreateGroupChannel(context.Background(), "reqr2", "room", "u1", []string{" "})
		}, "member id is empty"},
		{"join unknown channel", func(f *FakeClient) error {
			return f.JoinGroupChannel(context.Background(), "missing", []string{"u2"})
		}, "not found"},
		{"join too many members", func(f *FakeClient) error {
			return f.JoinGroupChannel(context.Background(), "reqr1", tooMany)
		}, "at most"},
		{"message unknown channel", func(f *FakeClient) error {
			return f.SendGroupMessage(context.Background(), "missing", "u1", "", "hi")
		}, "not found"},
		{"message missing sender", func(f *FakeClient) error {
			return f.SendGroupMessage(context.Background(), "reqr1", "", "", "hi")
		}, "required"},
		{"freeze unknown channel", func(f *FakeClient) error {
			return f.FreezeGroupChannel(context.Background(), "missing")
		}, "not found"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.call(setup())
			if err == nil {
				t.Fatalf("call succeeded, want error containing %q", tt.want)
			}
			if !strings.Contains(err.Error(), tt.want) {
				t.Errorf("error = %q, want it to contain %q", err, tt.want)
			}
		})
	}
}

func TestFakeClientConcurrentUse(t *testing.T) {
	f := NewFakeClient()
	if err := f.CreateGroupChannel(context.Background(), "reqr1", "room", "u1", nil); err != nil {
		t.Fatalf("CreateGroupChannel: %v", err)
	}

	const n = 20
	var wg sync.WaitGroup
	errs := make(chan error, n*2)
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			id := "u" + string(rune('a'+i))
			if _, err := f.IssueToken(context.Background(), id, "Donor"); err != nil {
				errs <- err
			}
			if err := f.JoinGroupChannel(context.Background(), "reqr1", []string{id}); err != nil {
				errs <- err
			}
		}(i)
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		t.Errorf("concurrent call: %v", err)
	}

	room, ok := f.Channel("reqr1")
	if !ok || len(room.Members) != n+1 {
		t.Errorf("members = %v, want %d", room.Members, n+1)
	}
}

func TestZeroValueFakeClientIsUsable(t *testing.T) {
	var f FakeClient
	if err := f.CreateGroupChannel(context.Background(), "reqr1", "room", "u1", nil); err != nil {
		t.Fatalf("CreateGroupChannel on zero value: %v", err)
	}
	if _, ok := f.Channel("reqr1"); !ok {
		t.Fatal("channel not found on zero value client")
	}
}
