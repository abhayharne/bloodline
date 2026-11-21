package store

// Donation is a donor's pledge to fulfil a request.
type Donation struct {
	ID        string `json:"id"`
	RequestID string `json:"request_id"`
	DonorID   string `json:"donor_id"`
	Units     int    `json:"units"`
	CreatedAt string `json:"created_at"`
}
