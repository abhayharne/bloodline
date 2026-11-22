// Package data holds the small reference datasets bundled into the API binary.
// Nothing here is patient data; the hospital directory is demo reference data
// served by GET /hospitals and used to resolve request hospital_id values.
package data

import (
	_ "embed"
	"encoding/json"
)

// Hospitals is the embedded demo directory (api/data/hospitals.json).
type Hospital struct {
	ID   string  `json:"id"`
	Name string  `json:"name"`
	Area string  `json:"area"`
	Lat  float64 `json:"lat"`
	Lng  float64 `json:"lng"`
}

//go:embed hospitals.json
var hospitalsJSON []byte

var hospitals = func() []Hospital {
	var list []Hospital
	if err := json.Unmarshal(hospitalsJSON, &list); err != nil {
		// The file is compiled into the binary; a parse error is a build-time
		// mistake and must fail loudly at startup, not silently serve nothing.
		panic("data: invalid embedded hospitals.json: " + err.Error())
	}
	return list
}()

// All returns a copy of the embedded directory, so callers can sort or filter
// it without mutating the shared slice.
func All() []Hospital {
	return append([]Hospital(nil), hospitals...)
}

// ByID resolves a hospital_id from GET /hospitals.
func ByID(id string) (Hospital, bool) {
	for _, hospital := range hospitals {
		if hospital.ID == id {
			return hospital, true
		}
	}
	return Hospital{}, false
}
