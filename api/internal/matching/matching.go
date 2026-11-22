// Package matching holds blood-group compatibility, donor eligibility and a
// composable DonorFilter pipeline. The pure helpers are tested now; the live
// request feed still uses D4's exact-group rule (see DATA_MODEL.md) so the
// seeded demo does not change silently. The pipeline is not wired in yet.
package matching

import (
	"math"
	"sort"
	"strings"
	"time"

	"bloodline/internal/store"
)

// Patient is the request side of a match.
type Patient struct {
	BloodGroup string
	Lat        float64
	Lng        float64
}

// Donor is the donor side of a match. Pointer fields mean "unknown" when nil;
// unknown availability does not exclude a donor, but unknown age or weight
// does (we cannot prove eligibility).
type Donor struct {
	ID            string
	BloodGroup    string
	Lat           float64
	Lng           float64
	Sex           string
	Age           *int
	WeightKG      *float64
	HeightCM      *float64
	DonatedBefore bool
	LastDonatedAt *time.Time
	Available     *bool
}

var groups = []string{"A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"}

// compatibleWith maps a patient's group to the donor groups it may receive.
var compatibleWith = map[string]map[string]bool{
	"O-":  allGroups(),
	"O+":  set("O+", "A+", "B+", "AB+"),
	"A-":  set("A+", "A-", "AB+", "AB-"),
	"A+":  set("A+", "AB+"),
	"B-":  set("B+", "B-", "AB+", "AB-"),
	"B+":  set("B+", "AB+"),
	"AB-": set("AB+", "AB-"),
	"AB+": set("AB+"),
}

func set(values ...string) map[string]bool {
	result := make(map[string]bool, len(values))
	for _, value := range values {
		result[value] = true
	}
	return result
}

func allGroups() map[string]bool { return set(groups...) }

var groupSet = allGroups()

// Component names shared by requests and bank stock.
const (
	ComponentWholeBlood = "whole_blood"
	ComponentRedCells   = "red_cells"
	ComponentPlatelets  = "platelets"
	ComponentPlasma     = "plasma"
	ComponentCryo       = "cryo"
	ComponentOther      = "other"
)

func normaliseComponent(component string) string {
	value := strings.ToLower(strings.TrimSpace(component))
	if value == "" {
		return ComponentWholeBlood
	}
	return value
}

// plasmaDonors maps a patient's ABO letter to the ABO letters whose plasma they
// may receive. It is the reverse of the red-cell chart, with Rh ignored: an O
// patient can receive any plasma (universal recipient) while an AB patient may
// only receive AB plasma. This matches the contract's `O<-all, A<-A,AB,
// B<-B,AB, AB<-AB` (patient <- acceptable donor groups).
var plasmaDonors = map[string]map[string]bool{
	"O":  set("O", "A", "B", "AB"),
	"A":  set("A", "AB"),
	"B":  set("B", "AB"),
	"AB": set("AB"),
}

func cleanGroup(group string) string {
	return strings.ToUpper(strings.TrimSpace(group))
}

func aboLetter(group string) string {
	value := cleanGroup(group)
	return strings.TrimSuffix(strings.TrimSuffix(value, "+"), "-")
}

func rhFactor(group string) string {
	if strings.HasSuffix(cleanGroup(group), "+") {
		return "+"
	}
	if strings.HasSuffix(cleanGroup(group), "-") {
		return "-"
	}
	return ""
}

// Compatible reports whether a donor of donorGroup may donate to a patient of
// patientGroup (ABO + Rh). It is pure and case-insensitive; unknown groups are
// never compatible.
func Compatible(patientGroup, donorGroup string) bool {
	return compatibleWith[cleanGroup(patientGroup)][cleanGroup(donorGroup)]
}

// CompatibleForComponent reports whether donorGroup can supply component to
// patientGroup. Red cells (and whole blood/other) use the ABO/Rh chart;
// plasma/cryo use reverse ABO with Rh ignored; platelets are ranked rather than
// excluded, so any valid group is acceptable and DonorRankForComponent decides
// the order.
func CompatibleForComponent(patientGroup, donorGroup, component string) bool {
	patient, donor := cleanGroup(patientGroup), cleanGroup(donorGroup)
	if !groupSet[patient] || !groupSet[donor] {
		return false
	}
	switch normaliseComponent(component) {
	case ComponentPlatelets:
		return true
	case ComponentPlasma, ComponentCryo:
		return plasmaDonors[aboLetter(patient)][aboLetter(donor)]
	default:
		return Compatible(patient, donor)
	}
}

// DonorRankForComponent returns a lower-is-better priority for a donor group,
// or -1 when the group cannot supply the component. Ties are broken by distance
// in the caller. Platelets prefer same ABO and Rh-negative donors for
// Rh-negative patients; other components rank exact matches first.
func DonorRankForComponent(patientGroup, donorGroup, component string) int {
	patient, donor := cleanGroup(patientGroup), cleanGroup(donorGroup)
	if !CompatibleForComponent(patient, donor, component) {
		return -1
	}
	if normaliseComponent(component) == ComponentPlatelets {
		sameABO := aboLetter(patient) == aboLetter(donor)
		rhOK := rhFactor(patient) != "-" || rhFactor(donor) == "-"
		switch {
		case sameABO && rhOK:
			return 0
		case sameABO:
			return 1
		case rhOK:
			return 2
		default:
			return 3
		}
	}
	switch {
	case patient == donor:
		return 0
	case aboLetter(patient) == aboLetter(donor):
		return 1
	default:
		return 2
	}
}

// CompatibleGroups returns every group that can supply component to the
// patient, best first. Used by the store queries for apheresis components.
func CompatibleGroups(patientGroup, component string) []string {
	result := make([]string, 0, len(groups))
	for _, group := range groups {
		if CompatibleForComponent(patientGroup, group, component) {
			result = append(result, group)
		}
	}
	sort.SliceStable(result, func(i, j int) bool {
		return DonorRankForComponent(patientGroup, result[i], component) <
			DonorRankForComponent(patientGroup, result[j], component)
	})
	return result
}

// requiredInterval is the waiting period after a donation: 90 days for male
// donors, 120 days for female, other or unspecified (the conservative choice).
func requiredInterval(donor Donor) time.Duration {
	if strings.EqualFold(strings.TrimSpace(donor.Sex), "male") {
		return 90 * 24 * time.Hour
	}
	return 120 * 24 * time.Hour
}

// Eligible reports whether a donor satisfies the demo's safety rules:
// age 18-65 inclusive, weight >= 45 kg, and enough time since the last
// donation (90 days for male, 120 days for female/unspecified). Unknown age
// or weight make eligibility false; an explicit available=false excludes.
func Eligible(donor Donor, now time.Time) bool {
	if donor.Available != nil && !*donor.Available {
		return false
	}
	if donor.Age == nil || *donor.Age < 18 || *donor.Age > 65 {
		return false
	}
	if donor.WeightKG == nil || *donor.WeightKG < 45 {
		return false
	}
	if donor.LastDonatedAt == nil {
		return true
	}
	return now.Sub(*donor.LastDonatedAt) >= requiredInterval(donor)
}

// NextEligibleAt returns the date from which the donor may give again, using
// the same interval as Eligible. It is nil when the last donation date is
// unknown or the waiting period has already elapsed (i.e. the donor is not
// waiting on the interval). It intentionally ignores age/weight/availability:
// those are separate concerns reported by Eligible.
func NextEligibleAt(donor Donor, now time.Time) *time.Time {
	if donor.LastDonatedAt == nil {
		return nil
	}
	next := donor.LastDonatedAt.Add(requiredInterval(donor))
	if !next.After(now) {
		return nil
	}
	return &next
}

// DonorFilter is one predicate of the matching pipeline.
type DonorFilter func(patient Patient, donor Donor, now time.Time) bool

// Pipeline applies filters in order; a donor must pass all of them.
type Pipeline struct {
	filters []DonorFilter
}

// NewPipeline composes filters in the given order. An empty pipeline accepts
// every donor.
func NewPipeline(filters ...DonorFilter) Pipeline {
	return Pipeline{filters: filters}
}

// Apply returns the donors that pass every filter, preserving input order.
func (p Pipeline) Apply(patient Patient, donors []Donor, now time.Time) []Donor {
	result := make([]Donor, 0, len(donors))
	for _, donor := range donors {
		passes := true
		for _, filter := range p.filters {
			if filter == nil {
				continue
			}
			if !filter(patient, donor, now) {
				passes = false
				break
			}
		}
		if passes {
			result = append(result, donor)
		}
	}
	return result
}

// ByCompatibility filters on the ABO/Rh chart.
func ByCompatibility() DonorFilter {
	return func(patient Patient, donor Donor, _ time.Time) bool {
		return Compatible(patient.BloodGroup, donor.BloodGroup)
	}
}

// ByDistance filters on haversine distance in km.
func ByDistance(radiusKM float64) DonorFilter {
	return func(patient Patient, donor Donor, _ time.Time) bool {
		return DistanceKM(patient.Lat, patient.Lng, donor.Lat, donor.Lng) <= radiusKM
	}
}

// ByAvailability excludes donors explicitly marked unavailable.
func ByAvailability() DonorFilter {
	return func(_ Patient, donor Donor, _ time.Time) bool {
		return donor.Available == nil || *donor.Available
	}
}

// ByEligibility applies the age/weight/interval rules.
func ByEligibility() DonorFilter {
	return func(_ Patient, donor Donor, now time.Time) bool {
		return Eligible(donor, now)
	}
}

// DistanceKM is the great-circle distance between two coordinates in km.
func DistanceKM(lat1, lng1, lat2, lng2 float64) float64 {
	const earthRadiusKM = 6371
	toRad := math.Pi / 180
	dLat := (lat2 - lat1) * toRad
	dLng := (lng2 - lng1) * toRad
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*toRad)*math.Cos(lat2*toRad)*math.Sin(dLng/2)*math.Sin(dLng/2)
	return 2 * earthRadiusKM * math.Asin(math.Sqrt(a))
}

// RankForCount returns the donor rank for a donation count. The thresholds are
// defined by addendum v2: 1 First Drop, 3 Helper, 5 Silver Lifeline,
// 10 Gold Lifeline, 25 Lifesaver. The highest reached rank wins.
func RankForCount(count int) (key, label string, ok bool) {
	switch {
	case count >= 25:
		return "lifesaver", "Lifesaver", true
	case count >= 10:
		return "gold_lifeline", "Gold Lifeline", true
	case count >= 5:
		return "silver_lifeline", "Silver Lifeline", true
	case count >= 3:
		return "helper", "Helper", true
	case count >= 1:
		return "first_drop", "First Drop", true
	default:
		return "", "", false
	}
}

// FromUser converts a store user into a matching donor profile.
func FromUser(user store.User) Donor {
	donor := Donor{
		ID:            user.ID,
		Lat:           user.Lat,
		Lng:           user.Lng,
		DonatedBefore: user.DonatedBefore,
	}
	if user.BloodGroup != nil {
		donor.BloodGroup = *user.BloodGroup
	}
	if user.Sex != nil {
		donor.Sex = *user.Sex
	}
	donor.Age = user.Age
	donor.WeightKG = user.WeightKG
	donor.HeightCM = user.HeightCM
	donor.LastDonatedAt = parseTime(user.LastDonatedAt)
	available := user.Available
	donor.Available = &available
	return donor
}

func parseTime(raw *string) *time.Time {
	if raw == nil || strings.TrimSpace(*raw) == "" {
		return nil
	}
	value := strings.TrimSpace(*raw)
	for _, layout := range []string{time.RFC3339, "2006-01-02", "2006-01-02 15:04:05"} {
		if parsed, err := time.Parse(layout, value); err == nil {
			return &parsed
		}
	}
	return nil
}
