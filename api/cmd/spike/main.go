// Command spike is a THROWAWAY proof-of-concept for PLAN task T0.3.
//
// It proves the three Nexconn Server API calls the BloodLine backend will need:
//
//	(a) POST /v4/auth/access-token/issue  -> mint a user token for "test1"
//	(b) POST /v4/group-channel/create     -> create a group channel
//	(c) POST /v4/group-channel/join       -> add a member to that channel
//
// It uses the official Go server SDK (github.com/NexconnAI-Dev/nexconn-server-sdk-go),
// which signs every request with Signature = sha1(AppSecret + Nonce + Timestamp)
// and generates Nonce / Timestamp / X-Request-ID headers automatically.
//
// Run from the repo root or from api/:
//
//	go run ./cmd/spike            # from api/
//	go run ./api/cmd/spike        # from repo root
//
// Flags:
//
//	-channel  explicit channel id (default: blspike<unix seconds>)
//	-owner    user id that owns the group (default: test1)
//	-member   user id to add to the group (default: test2)
//	-debug    dump full HTTP request/response bodies (App Secret is never logged)
//
// Credentials are read from .env at the repo root (or from the environment).
// Delete this directory once T0.3 is signed off.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	ncsdk "github.com/NexconnAI-Dev/nexconn-server-sdk-go"
)

func main() {
	channelID := flag.String("channel", fmt.Sprintf("blspike%d", time.Now().Unix()), "group channel id (alphanumeric, max 64)")
	owner := flag.String("owner", "test1", "owner user id")
	member := flag.String("member", "test2", "user id to add to the group")
	debug := flag.Bool("debug", false, "dump full HTTP requests/responses")
	flag.Parse()

	if err := run(*channelID, *owner, *member, *debug); err != nil {
		fmt.Fprintf(os.Stderr, "\nFAILED: %v\n", err)
		os.Exit(1)
	}
}

func run(channelID, owner, member string, debug bool) error {
	if err := loadDotEnv(); err != nil {
		return err
	}

	appKey := os.Getenv("NEXCONN_APP_KEY")
	appSecret := os.Getenv("NEXCONN_APP_SECRET")
	primary := os.Getenv("NEXCONN_API_BASE")
	backup := os.Getenv("NEXCONN_API_BASE_BACKUP")
	if appKey == "" || appSecret == "" || primary == "" || backup == "" {
		return errors.New("NEXCONN_APP_KEY, NEXCONN_APP_SECRET, NEXCONN_API_BASE and NEXCONN_API_BASE_BACKUP must be set (see .env.example)")
	}

	cfg := ncsdk.NewConfiguration()
	cfg.SetNexconnCredentials(appKey, appSecret)
	cfg.Debug = debug
	if err := cfg.SetPrimaryBackupDomains(primary, backup); err != nil {
		return fmt.Errorf("configure domains: %w", err)
	}

	client := ncsdk.NewAPIClient(cfg)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	fmt.Printf("Nexconn spike -> %s (backup %s)\n\n", primary, backup)

	// (a) Mint an access token for the owner. This also registers the user.
	fmt.Printf("(a) POST /v4/auth/access-token/issue  userId=%q\n", owner)
	tokenReq := ncsdk.NewAccessTokenIssueRequest(owner, "BloodLine Test One")
	tokenResp, _, err := client.UserManagementAPI.IssueAccessToken(ctx).
		AccessTokenIssueRequest(*tokenReq).
		Execute()
	if err != nil {
		return fmt.Errorf("issue access token: %w", err)
	}
	if tokenResp.Result == nil || tokenResp.Result.AccessToken == nil {
		return errors.New("issue access token: response has no accessToken")
	}
	token := *tokenResp.Result.AccessToken
	fmt.Printf("    code=%d userId=%q accessToken len=%d prefix=%q\n\n",
		tokenResp.Code, deref(tokenResp.Result.UserId), len(token), token[:min(12, len(token))])

	// (b) Create the group channel. The creator (owner) joins automatically.
	fmt.Printf("(b) POST /v4/group-channel/create  channelId=%q owner=%q\n", channelID, owner)
	createReq := ncsdk.NewGroupChannelCreateRequest(channelID, "BloodLine spike room", owner)
	createResp, _, err := client.GroupChannelManagementAPI.CreateGroupChannel(ctx).
		GroupChannelCreateRequest(*createReq).
		Execute()
	if err != nil {
		return fmt.Errorf("create group channel: %w", err)
	}
	fmt.Printf("    code=%d\n\n", createResp.Code)

	// (c) Add a member. "join" adds users without approval (max 100 per call).
	fmt.Printf("(c) POST /v4/group-channel/join  channelId=%q userIds=[%q]\n", channelID, member)
	joinReq := ncsdk.NewGroupChannelJoinRequest(channelID, []string{member})
	joinResp, _, err := client.GroupChannelManagementAPI.JoinGroupChannel(ctx).
		GroupChannelJoinRequest(*joinReq).
		Execute()
	if err != nil {
		return fmt.Errorf("join group channel: %w", err)
	}
	if joinResp.Result != nil {
		body, _ := json.Marshal(joinResp.Result)
		fmt.Printf("    code=%d result=%s\n\n", joinResp.Code, body)
	} else {
		fmt.Printf("    code=%d\n\n", joinResp.Code)
	}

	fmt.Println("OK — all three calls succeeded.")
	fmt.Printf("CHANNEL_ID=%s  (open it in the app as user %q to verify)\n", channelID, owner)
	return nil
}

// loadDotEnv reads KEY=VALUE lines from the nearest .env walking up from the
// working directory. Existing environment variables win, so nothing is
// overridden. This keeps credentials out of the source tree.
func loadDotEnv() error {
	dir, err := os.Getwd()
	if err != nil {
		return err
	}
	for i := 0; i < 5; i++ {
		path := filepath.Join(dir, ".env")
		if _, statErr := os.Stat(path); statErr == nil {
			return parseEnvFile(path)
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return fmt.Errorf("no .env found in %s or its parents (copy .env.example to .env)", dir)
}

func parseEnvFile(path string) error {
	raw, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	for _, line := range strings.Split(string(raw), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		key = strings.TrimSpace(key)
		value = strings.TrimSpace(value)
		value = strings.Trim(value, `"'`)
		if key == "" {
			continue
		}
		if _, exists := os.LookupEnv(key); !exists {
			if err := os.Setenv(key, value); err != nil {
				return err
			}
		}
	}
	return nil
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
