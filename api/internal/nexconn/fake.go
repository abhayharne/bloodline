package nexconn

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"sync"
)

// FakeClient is an in-memory implementation of Client for offline demos and
// tests (NEXCONN_FAKE=1). It makes no network calls and holds no credentials.
// Its state is per process and is intentionally not persisted.
type FakeClient struct {
	mu       sync.Mutex
	users    map[string]string
	channels map[string]*fakeChannel
}

// FakeChannel is a read-only snapshot of a room held by FakeClient.
type FakeChannel struct {
	ID       string
	Name     string
	Owner    string
	Members  []string
	Frozen   bool
	Messages []FakeMessage
}

// FakeMessage is one message recorded by FakeClient.
type FakeMessage struct {
	ChannelID  string
	FromUserID string
	Type       string
	Content    string
}

type fakeChannel struct {
	name     string
	owner    string
	members  map[string]string // user id -> name, if known
	frozen   bool
	messages []FakeMessage
}

const (
	fakeTokenPrefix = "fake-chat-token-"
	maxJoinMembers  = 100 // matches the SDK's join limit
)

var _ Client = (*FakeClient)(nil)

// NewFakeClient returns an empty in-memory chat client.
func NewFakeClient() *FakeClient {
	return &FakeClient{
		users:    make(map[string]string),
		channels: make(map[string]*fakeChannel),
	}
}

// IssueToken records the user and returns a deterministic dummy chat token.
func (f *FakeClient) IssueToken(ctx context.Context, userID, name string) (string, error) {
	if err := contextErr(ctx); err != nil {
		return "", err
	}
	userID = strings.TrimSpace(userID)
	name = strings.TrimSpace(name)
	if userID == "" || name == "" {
		return "", errors.New("nexconn fake: user id and name are required")
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	f.init()
	f.users[userID] = name
	return fakeTokenPrefix + userID, nil
}

// CreateGroupChannel creates a room with owner and userIDs as its members.
func (f *FakeClient) CreateGroupChannel(ctx context.Context, channelID, name, owner string, userIDs []string) error {
	if err := contextErr(ctx); err != nil {
		return err
	}
	channelID = strings.TrimSpace(channelID)
	owner = strings.TrimSpace(owner)
	if channelID == "" || owner == "" {
		return errors.New("nexconn fake: channel id and owner are required")
	}
	if len(userIDs) > maxJoinMembers {
		return fmt.Errorf("nexconn fake: at most %d members per call", maxJoinMembers)
	}
	for _, id := range userIDs {
		if strings.TrimSpace(id) == "" {
			return errors.New("nexconn fake: member id is empty")
		}
	}

	f.mu.Lock()
	defer f.mu.Unlock()
	f.init()
	if _, exists := f.channels[channelID]; exists {
		return fmt.Errorf("nexconn fake: channel %q already exists", channelID)
	}
	ch := &fakeChannel{name: name, owner: owner, members: make(map[string]string)}
	ch.members[owner] = f.users[owner]
	for _, id := range userIDs {
		ch.members[id] = f.users[id]
	}
	f.channels[channelID] = ch
	return nil
}

// JoinGroupChannel adds members to an existing room; re-joining is idempotent.
func (f *FakeClient) JoinGroupChannel(ctx context.Context, channelID string, userIDs []string) error {
	if err := contextErr(ctx); err != nil {
		return err
	}
	if strings.TrimSpace(channelID) == "" {
		return errors.New("nexconn fake: channel id is required")
	}
	if len(userIDs) > maxJoinMembers {
		return fmt.Errorf("nexconn fake: at most %d members per call", maxJoinMembers)
	}
	for _, id := range userIDs {
		if strings.TrimSpace(id) == "" {
			return errors.New("nexconn fake: member id is empty")
		}
	}

	f.mu.Lock()
	defer f.mu.Unlock()
	f.init()
	ch, ok := f.channels[channelID]
	if !ok {
		return fmt.Errorf("nexconn fake: channel %q not found", channelID)
	}
	for _, id := range userIDs {
		ch.members[id] = f.users[id]
	}
	return nil
}

// SendGroupMessage records a message. Frozen rooms reject new messages.
func (f *FakeClient) SendGroupMessage(ctx context.Context, channelID, fromUserID, messageType, content string) error {
	if err := contextErr(ctx); err != nil {
		return err
	}
	if strings.TrimSpace(channelID) == "" || strings.TrimSpace(fromUserID) == "" {
		return errors.New("nexconn fake: channel id and sender are required")
	}
	if messageType == "" {
		messageType = "RC:TxtMsg"
	}

	f.mu.Lock()
	defer f.mu.Unlock()
	f.init()
	ch, ok := f.channels[channelID]
	if !ok {
		return fmt.Errorf("nexconn fake: channel %q not found", channelID)
	}
	if ch.frozen {
		return fmt.Errorf("nexconn fake: channel %q is frozen", channelID)
	}
	ch.messages = append(ch.messages, FakeMessage{
		ChannelID: channelID, FromUserID: fromUserID, Type: messageType, Content: content,
	})
	return nil
}

// FreezeGroupChannel freezes a room; calling it again is idempotent.
func (f *FakeClient) FreezeGroupChannel(ctx context.Context, channelID string) error {
	if err := contextErr(ctx); err != nil {
		return err
	}
	if strings.TrimSpace(channelID) == "" {
		return errors.New("nexconn fake: channel id is required")
	}

	f.mu.Lock()
	defer f.mu.Unlock()
	f.init()
	ch, ok := f.channels[channelID]
	if !ok {
		return fmt.Errorf("nexconn fake: channel %q not found", channelID)
	}
	ch.frozen = true
	return nil
}

// Channel returns a snapshot of a room, for tests and local diagnostics.
func (f *FakeClient) Channel(channelID string) (FakeChannel, bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.init()
	ch, ok := f.channels[channelID]
	if !ok {
		return FakeChannel{}, false
	}
	members := make([]string, 0, len(ch.members))
	for id := range ch.members {
		members = append(members, id)
	}
	sort.Strings(members)
	return FakeChannel{
		ID:       channelID,
		Name:     ch.name,
		Owner:    ch.owner,
		Members:  members,
		Frozen:   ch.frozen,
		Messages: append([]FakeMessage(nil), ch.messages...),
	}, true
}

func (f *FakeClient) init() {
	if f.users == nil {
		f.users = make(map[string]string)
	}
	if f.channels == nil {
		f.channels = make(map[string]*fakeChannel)
	}
}

func contextErr(ctx context.Context) error {
	if ctx == nil {
		return nil
	}
	return ctx.Err()
}
