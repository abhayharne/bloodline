package notify

import (
	"context"
	"errors"
	"path/filepath"
	"testing"

	"bloodline/internal/events"
	"bloodline/internal/store"
)

func TestNotifierWritesOneRowPerRecipient(t *testing.T) {
	st, err := store.Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatalf("store.Open: %v", err)
	}
	defer st.Close()

	n := New(st)
	n.Handle(context.Background(), events.Event{
		Name: events.RequestCreated,
		Payload: events.RequestCreatedPayload{
			RequestID:    "r1",
			BloodGroup:   "O-",
			Hospital:     "City Hospital",
			Units:        2,
			RecipientIDs: []string{"udon1", "ubank1"},
		},
	})

	for _, userID := range []string{"udon1", "ubank1"} {
		items, err := st.Notifications(context.Background(), userID)
		if err != nil {
			t.Fatalf("Notifications: %v", err)
		}
		if len(items) != 1 {
			t.Fatalf("%s notifications = %d, want 1", userID, len(items))
		}
		if items[0].Type != events.RequestCreated || items[0].Title == "" || items[0].Body == "" {
			t.Errorf("notification = %+v", items[0])
		}
		if items[0].RequestID == nil || *items[0].RequestID != "r1" {
			t.Errorf("request_id = %v", items[0].RequestID)
		}
	}
}

func TestNotifierHandlesAcceptedAndFulfilled(t *testing.T) {
	st, err := store.Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatalf("store.Open: %v", err)
	}
	defer st.Close()

	n := New(st)
	n.Handle(context.Background(), events.Event{
		Name:    events.RequestAccepted,
		Payload: events.RequestAcceptedPayload{RequestID: "r1", RequesterID: "ureq1", UserName: "Asha", UserRole: "donor"},
	})
	n.Handle(context.Background(), events.Event{
		Name:    events.RequestFulfilled,
		Payload: events.RequestFulfilledPayload{RequestID: "r1", RecipientIDs: []string{"udon1"}, BloodGroup: "O-", Hospital: "City Hospital"},
	})

	requester, err := st.Notifications(context.Background(), "ureq1")
	if err != nil {
		t.Fatal(err)
	}
	if len(requester) != 1 || requester[0].Type != events.RequestAccepted {
		t.Errorf("requester notifications = %+v", requester)
	}
	donor, err := st.Notifications(context.Background(), "udon1")
	if err != nil {
		t.Fatal(err)
	}
	if len(donor) != 1 || donor[0].Type != events.RequestFulfilled {
		t.Errorf("donor notifications = %+v", donor)
	}
}

func TestNotifierIgnoresUnknownPayloads(t *testing.T) {
	st, err := store.Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatalf("store.Open: %v", err)
	}
	defer st.Close()

	New(st).Handle(context.Background(), events.Event{Name: "unknown.event", Payload: "anything"})
	items, err := st.Notifications(context.Background(), "u1")
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 0 {
		t.Errorf("notifications = %+v, want empty", items)
	}
}

type failingStore struct{}

func (failingStore) InsertNotification(context.Context, store.Notification) error {
	return errors.New("db down")
}

func TestNotifierSurvivesStoreErrors(t *testing.T) {
	New(failingStore{}).Handle(context.Background(), events.Event{
		Name:    events.RequestCreated,
		Payload: events.RequestCreatedPayload{RequestID: "r1", RecipientIDs: []string{"udon1"}},
	})
}

// flakyStore fails only the first write so we can prove one bad write does not
// stop the rest of the recipients.
type flakyStore struct {
	calls   int
	written []string
}

func (f *flakyStore) InsertNotification(_ context.Context, n store.Notification) error {
	f.calls++
	if f.calls == 1 {
		return errors.New("db down")
	}
	f.written = append(f.written, n.UserID)
	return nil
}

func TestNotifierContinuesAfterOneWriteFails(t *testing.T) {
	st := &flakyStore{}
	New(st).Handle(context.Background(), events.Event{
		Name: events.RequestCreated,
		Payload: events.RequestCreatedPayload{
			RequestID: "r1", RecipientIDs: []string{"ubad", "ugood1", "ugood2"},
		},
	})
	if len(st.written) != 2 || st.written[0] != "ugood1" || st.written[1] != "ugood2" {
		t.Fatalf("written = %v, want [ugood1 ugood2]", st.written)
	}
}
