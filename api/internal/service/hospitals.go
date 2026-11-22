package service

import (
	"sort"
	"strings"

	"bloodline/data"
	"bloodline/internal/matching"
)

// Hospital is the client-facing shape of one embedded directory entry.
type Hospital = data.Hospital

// HospitalQuery is the validated shape of GET /hospitals. Pointer coordinates
// let the handler distinguish an omitted parameter from an explicit zero.
type HospitalQuery struct {
	Q        string
	Lat, Lng *float64
	Limit    *int
}

// Hospitals searches the embedded directory. Every bad combination is a
// ValidationError so the handler can return 400 with a specific message.
func (s *Service) Hospitals(q HospitalQuery) ([]Hospital, error) {
	limit := 20
	if q.Limit != nil {
		limit = *q.Limit
	}
	if limit < 1 || limit > 50 {
		return nil, invalid("limit must be between 1 and 50")
	}
	if (q.Lat == nil) != (q.Lng == nil) {
		return nil, invalid("lat and lng must be supplied together")
	}
	if q.Lat != nil {
		if err := validateCoordinates(*q.Lat, *q.Lng); err != nil {
			return nil, err
		}
	}

	needle := strings.ToLower(strings.TrimSpace(q.Q))
	matches := make([]Hospital, 0)
	for _, hospital := range data.All() {
		if needle != "" && !strings.Contains(strings.ToLower(hospital.Name), needle) &&
			!strings.Contains(strings.ToLower(hospital.Area), needle) {
			continue
		}
		matches = append(matches, hospital)
	}

	if q.Lat != nil {
		lat, lng := *q.Lat, *q.Lng
		sort.SliceStable(matches, func(i, j int) bool {
			di := matching.DistanceKM(lat, lng, matches[i].Lat, matches[i].Lng)
			dj := matching.DistanceKM(lat, lng, matches[j].Lat, matches[j].Lng)
			if di != dj {
				return di < dj
			}
			return matches[i].Name < matches[j].Name
		})
	} else {
		sort.SliceStable(matches, func(i, j int) bool {
			if matches[i].Name != matches[j].Name {
				return matches[i].Name < matches[j].Name
			}
			return matches[i].ID < matches[j].ID
		})
	}
	if len(matches) > limit {
		matches = matches[:limit]
	}
	return matches, nil
}
