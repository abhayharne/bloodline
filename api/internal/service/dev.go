package service

import "context"

// Reset reloads the demo dataset. The HTTP layer exposes this only when DEV=1.
func (s *Service) Reset(ctx context.Context) error {
	return s.store.Reseed(ctx)
}
