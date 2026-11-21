// Package nexconn wraps the Nexconn server SDK behind a small interface so the
// service layer can be tested with a fake and handlers never touch credentials.
//
// Credentials and access tokens are never logged here.
package nexconn

import (
	"context"
	"errors"
	"fmt"

	ncsdk "github.com/NexconnAI-Dev/nexconn-server-sdk-go"
)

// Client is the subset of Nexconn server operations BloodLine needs.
type Client interface {
	// IssueToken registers the user if needed and returns a chat access token.
	IssueToken(ctx context.Context, userID, name string) (string, error)
	// CreateGroupChannel creates a group owned by owner and optionally adds members.
	CreateGroupChannel(ctx context.Context, channelID, name, owner string, userIDs []string) error
	// JoinGroupChannel adds members to an existing group channel.
	JoinGroupChannel(ctx context.Context, channelID string, userIDs []string) error
}

// SDKClient is the production implementation backed by the official Go SDK.
type SDKClient struct {
	api *ncsdk.APIClient
}

// New configures the SDK client. All four arguments are required; both API
// bases are needed because the SDK has no built-in default domain.
func New(appKey, appSecret, primaryBase, backupBase string) (*SDKClient, error) {
	if appKey == "" || appSecret == "" || primaryBase == "" || backupBase == "" {
		return nil, errors.New("nexconn: app key, app secret and both API bases are required")
	}

	cfg := ncsdk.NewConfiguration()
	cfg.SetNexconnCredentials(appKey, appSecret)
	// Never enable SDK debug logging: it can print credentials and tokens.
	cfg.Debug = false
	if err := cfg.SetPrimaryBackupDomains(primaryBase, backupBase); err != nil {
		return nil, fmt.Errorf("nexconn: configure domains: %w", err)
	}

	return &SDKClient{api: ncsdk.NewAPIClient(cfg)}, nil
}

// IssueToken mints a chat access token. The same call registers a new user.
func (c *SDKClient) IssueToken(ctx context.Context, userID, name string) (string, error) {
	req := ncsdk.NewAccessTokenIssueRequest(userID, name)
	resp, _, err := c.api.UserManagementAPI.IssueAccessToken(ctx).
		AccessTokenIssueRequest(*req).
		Execute()
	if err != nil {
		return "", fmt.Errorf("nexconn: issue access token: %w", err)
	}
	if resp == nil {
		return "", errors.New("nexconn: issue access token: empty response")
	}
	if resp.Code != 0 {
		return "", fmt.Errorf("nexconn: issue access token: code %d", resp.Code)
	}
	if resp.Result == nil || resp.Result.AccessToken == nil || *resp.Result.AccessToken == "" {
		return "", errors.New("nexconn: issue access token: response has no accessToken")
	}
	return *resp.Result.AccessToken, nil
}

// CreateGroupChannel creates a group channel; the owner joins automatically.
func (c *SDKClient) CreateGroupChannel(ctx context.Context, channelID, name, owner string, userIDs []string) error {
	if channelID == "" {
		return errors.New("nexconn: channel id is empty")
	}
	req := ncsdk.NewGroupChannelCreateRequest(channelID, name, owner)
	if len(userIDs) > 0 {
		req.SetUserIds(userIDs)
	}
	resp, _, err := c.api.GroupChannelManagementAPI.CreateGroupChannel(ctx).
		GroupChannelCreateRequest(*req).
		Execute()
	if err != nil {
		return fmt.Errorf("nexconn: create group channel: %w", err)
	}
	if resp == nil {
		return errors.New("nexconn: create group channel: empty response")
	}
	if resp.Code != 0 {
		return fmt.Errorf("nexconn: create group channel: code %d", resp.Code)
	}
	return nil
}

// JoinGroupChannel adds members without approval (max 100 per call).
func (c *SDKClient) JoinGroupChannel(ctx context.Context, channelID string, userIDs []string) error {
	if channelID == "" {
		return errors.New("nexconn: channel id is empty")
	}
	req := ncsdk.NewGroupChannelJoinRequest(channelID, userIDs)
	resp, _, err := c.api.GroupChannelManagementAPI.JoinGroupChannel(ctx).
		GroupChannelJoinRequest(*req).
		Execute()
	if err != nil {
		return fmt.Errorf("nexconn: join group channel: %w", err)
	}
	if resp == nil {
		return errors.New("nexconn: join group channel: empty response")
	}
	if resp.Code != 0 {
		return fmt.Errorf("nexconn: join group channel: code %d", resp.Code)
	}
	return nil
}
