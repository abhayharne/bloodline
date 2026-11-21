package store

import (
	"context"
	"errors"
	"path/filepath"
	"testing"

	"bloodline/internal/events"
)

func seedNotification(t *testing.T, st *Store, id, userID string) {
	t.Helper()
	err := st.InsertNotification(context.Background(), Notification{
		ID: id, UserID: userID, Type: events.RequestCreated, Title: "t", Body: "b",
	})
	if err != nil {
		t.Fatalf("InsertNotification(%s): %v", id, err)
	}
}

func TestMarkNotificationReadIsIdempotent(t *testing.T) {
	st, err := Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	defer st.Close()
	ctx := context.Background()
	seedNotification(t, st, "n1", "u1")

	if err := st.MarkNotificationRead(ctx, "n1", "u1"); err != nil {
		t.Fatalf("first MarkNotificationRead: %v", err)
	}
	if err := st.MarkNotificationRead(ctx, "n1", "u1"); err != nil {
		t.Fatalf("second MarkNotificationRead (idempotent): %v", err)
	}

	items, err := st.Notifications(ctx, "u1")
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || !items[0].Read || items[0].ReadAt == nil {
		t.Fatalf("notification = %+v, want Read=true and read_at set", items)
	}
}

func TestMarkNotificationReadIsOwnerScoped(t *testing.T) {
	st, err := Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	defer st.Close()
	ctx := context.Background()
	seedNotification(t, st, "n1", "u1")

	if err := st.MarkNotificationRead(ctx, "n1", "someone-else"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("mark as other user: err = %v, want ErrNotFound", err)
	}
	// The failed attempt did not mutate the row.
	items, err := st.Notifications(ctx, "u1")
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || items[0].Read {
		t.Fatalf("notification = %+v, want still unread", items)
	}
}

func TestMarkNotificationReadMissingIsNotFound(t *testing.T) {
	st, err := Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	defer st.Close()

	if err := st.MarkNotificationRead(context.Background(), "nope", "u1"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("err = %v, want ErrNotFound", err)
	}
}

func TestHasNotification(t *testing.T) {
	st, err := Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer st.Close()
	ctx := context.Background()
	seedNotification(t, st, "n1", "u1")
	// seedNotification uses type request.created, body "b"
	ok, err := st.HasNotification(ctx, "u1", "request.created", "b")
	if err != nil || !ok {
		t.Fatalf("ok=%v err=%v, want true", ok, err)
	}
	ok, err = st.HasNotification(ctx, "u1", "rank_up", "b")
	if err != nil || ok {
		t.Fatalf("ok=%v err=%v, want false", ok, err)
	}
	ok, err = st.HasNotification(ctx, "u2", "request.created", "b")
	if err != nil || ok {
		t.Fatalf("other user ok=%v err=%v, want false", ok, err)
	}
}
