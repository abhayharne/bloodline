package matching

import (
	"testing"
	"time"

	"bloodline/internal/store"
)

func TestCompatibleChart(t *testing.T) {
	tests := []struct {
		patient string
		donor   string
		want    bool
	}{
		{"O-", "O-", true}, {"O-", "O+", true}, {"O-", "AB+", true},
		{"O+", "O-", false}, {"O+", "O+", true}, {"O+", "A+", true},
		{"O+", "B+", true}, {"O+", "AB+", true}, {"O+", "A-", false},
		{"A-", "A-", true}, {"A-", "A+", true}, {"A-", "AB+", true}, {"A-", "AB-", true},
		{"A-", "B+", false}, {"A+", "A+", true}, {"A+", "AB+", true},
		{"A+", "A-", false}, {"A+", "O-", false},
		{"B-", "B-", true}, {"B-", "B+", true}, {"B-", "AB-", true}, {"B-", "AB+", true},
		{"B+", "B+", true}, {"B+", "AB+", true}, {"B+", "B-", false},
		{"AB-", "AB-", true}, {"AB-", "AB+", true}, {"AB-", "O+", false},
		{"AB+", "AB+", true}, {"AB+", "A+", false}, {"AB+", "O-", false},
		{" o+ ", "a+", true}, {"O+", "Z+", false}, {"", "O+", false},
	}
	for _, tc := range tests {
		if got := Compatible(tc.patient, tc.donor); got != tc.want {
			t.Errorf("Compatible(%q, %q) = %v, want %v", tc.patient, tc.donor, got, tc.want)
		}
	}
}

func allCompatiblePairs() int {
	total := 0
	for patient := range compatibleWith {
		for _, donor := range groups {
			if Compatible(patient, donor) {
				total++
			}
		}
	}
	return total
}

func TestCompatibleChartCoversAllGroups(t *testing.T) {
	// O- -> 8, O+ -> 4, A- -> 4, A+ -> 2, B- -> 4, B+ -> 2, AB- -> 2, AB+ -> 1
	if got := allCompatiblePairs(); got != 27 {
		t.Errorf("compatible pairs = %d, want 27", got)
	}
}

func eligibleDonor() Donor {
	age, weight := 30, 60.0
	available := true
	return Donor{Age: &age, WeightKG: &weight, Available: &available, Sex: "male"}
}

func TestEligibleBoundaries(t *testing.T) {
	now := time.Date(2026, 11, 22, 12, 0, 0, 0, time.UTC)
	tests := []struct {
		name  string
		build func() Donor
		want  bool
	}{
		{"healthy donor", eligibleDonor, true},
		{"age 18", func() Donor { d := eligibleDonor(); age := 18; d.Age = &age; return d }, true},
		{"age 65", func() Donor { d := eligibleDonor(); age := 65; d.Age = &age; return d }, true},
		{"age 17", func() Donor { d := eligibleDonor(); age := 17; d.Age = &age; return d }, false},
		{"age 66", func() Donor { d := eligibleDonor(); age := 66; d.Age = &age; return d }, false},
		{"age unknown", func() Donor { d := eligibleDonor(); d.Age = nil; return d }, false},
		{"weight 45", func() Donor { d := eligibleDonor(); w := 45.0; d.WeightKG = &w; return d }, true},
		{"weight 44", func() Donor { d := eligibleDonor(); w := 44.9; d.WeightKG = &w; return d }, false},
		{"weight unknown", func() Donor { d := eligibleDonor(); d.WeightKG = nil; return d }, false},
		{"unavailable", func() Donor { d := eligibleDonor(); v := false; d.Available = &v; return d }, false},
		{"availability unknown", func() Donor { d := eligibleDonor(); d.Available = nil; return d }, true},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := Eligible(tc.build(), now); got != tc.want {
				t.Errorf("Eligible() = %v, want %v", got, tc.want)
			}
		})
	}
}

func TestEligibleDonationIntervals(t *testing.T) {
	now := time.Date(2026, 11, 22, 12, 0, 0, 0, time.UTC)
	tests := []struct {
		name string
		sex  string
		days int
		want bool
	}{
		{"male 89 days", "male", 89, false},
		{"male 90 days", "male", 90, true},
		{"female 119 days", "female", 119, false},
		{"female 120 days", "female", 120, true},
		{"other 120 days", "other", 120, true},
		{"other 90 days", "other", 90, false},
		{"unspecified 90 days", "", 90, false},
		{"future donation", "male", -1, false},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			donor := eligibleDonor()
			donor.Sex = tc.sex
			last := now.AddDate(0, 0, -tc.days)
			donor.LastDonatedAt = &last
			if got := Eligible(donor, now); got != tc.want {
				t.Errorf("Eligible() = %v, want %v", got, tc.want)
			}
		})
	}
}

func TestNextEligibleAt(t *testing.T) {
	now := time.Date(2026, 11, 22, 12, 0, 0, 0, time.UTC)
	if got := NextEligibleAt(eligibleDonor(), now); got != nil {
		t.Fatalf("no last donation: NextEligibleAt = %v, want nil", got)
	}

	recent := now.AddDate(0, 0, -10)
	donor := eligibleDonor()
	donor.LastDonatedAt = &recent
	got := NextEligibleAt(donor, now)
	want := recent.Add(90 * 24 * time.Hour)
	if got == nil || !got.Equal(want) {
		t.Fatalf("male 10 days ago = %v, want %v", got, want)
	}
	if Eligible(donor, now) {
		t.Error("donor 10 days after donating must not be eligible")
	}

	donor.Sex = "female"
	got = NextEligibleAt(donor, now)
	want = recent.Add(120 * 24 * time.Hour)
	if got == nil || !got.Equal(want) {
		t.Fatalf("female 10 days ago = %v, want %v", got, want)
	}

	old := now.AddDate(0, 0, -200)
	donor.LastDonatedAt = &old
	if got := NextEligibleAt(donor, now); got != nil {
		t.Fatalf("waiting period already elapsed: NextEligibleAt = %v, want nil", got)
	}
}

func TestPipelineAppliesAllFilters(t *testing.T) {
	now := time.Date(2026, 11, 22, 12, 0, 0, 0, time.UTC)
	patient := Patient{BloodGroup: "O+", Lat: 21.15, Lng: 79.09}
	age, weight := 30, 60.0
	available := true
	recent := now.AddDate(0, 0, -10)
	old := now.AddDate(0, 0, -200)
	mkDonor := func(id, group string, lat float64, last *time.Time) Donor {
		return Donor{
			ID: id, BloodGroup: group, Lat: lat, Lng: 79.09, Sex: "male",
			Age: &age, WeightKG: &weight, Available: &available, LastDonatedAt: last,
		}
	}
	donors := []Donor{
		mkDonor("d1", "O+", 21.15, nil),
		mkDonor("d2", "O-", 21.16, nil),
		mkDonor("d3", "O+", 22.5, nil),
		mkDonor("d4", "O+", 21.15, &recent),
		mkDonor("d5", "O+", 21.15, &old),
	}

	filtered := NewPipeline(
		ByCompatibility(), ByDistance(10), ByAvailability(), ByEligibility(),
	).Apply(patient, donors, now)
	if len(filtered) != 2 || filtered[0].ID != "d1" || filtered[1].ID != "d5" {
		ids := make([]string, 0, len(filtered))
		for _, d := range filtered {
			ids = append(ids, d.ID)
		}
		t.Fatalf("filtered ids = %v, want [d1 d5]", ids)
	}
}

func TestDistanceKM(t *testing.T) {
	if got := DistanceKM(21.1458, 79.0882, 21.1458, 79.0882); got != 0 {
		t.Errorf("same point distance = %v, want 0", got)
	}
	got := DistanceKM(21.1458, 79.0882, 21.25, 79.20)
	if got < 10 || got > 25 {
		t.Errorf("Nagpur offset distance = %v, want roughly 15 km", got)
	}
}

func TestFromUser(t *testing.T) {
	group, sex, last := "O+", "female", "2026-01-01"
	age, weight := 28, 58.0
	donor := FromUser(store.User{
		ID: "udon1", BloodGroup: &group, Sex: &sex, Age: &age, WeightKG: &weight,
		LastDonatedAt: &last, Available: true, Lat: 21.1, Lng: 79.1,
	})
	if donor.ID != "udon1" || donor.BloodGroup != "O+" || donor.Sex != "female" ||
		donor.Age == nil || *donor.Age != 28 || donor.WeightKG == nil || *donor.WeightKG != 58 ||
		donor.LastDonatedAt == nil || donor.Available == nil || !*donor.Available {
		t.Fatalf("FromUser = %+v", donor)
	}
	now := time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC)
	if Eligible(donor, now) {
		t.Error("female donor with 90 days since donation should not be eligible")
	}
	now = time.Date(2026, 5, 1, 0, 0, 0, 0, time.UTC)
	if !Eligible(donor, now) {
		t.Error("female donor with 120 days since donation should be eligible")
	}
}

func TestRankForCount(t *testing.T) {
	tests := []struct {
		count int
		key   string
		label string
		ok    bool
	}{
		{0, "", "", false},
		{1, "first_drop", "First Drop", true},
		{2, "first_drop", "First Drop", true},
		{3, "helper", "Helper", true},
		{4, "helper", "Helper", true},
		{5, "silver_lifeline", "Silver Lifeline", true},
		{9, "silver_lifeline", "Silver Lifeline", true},
		{10, "gold_lifeline", "Gold Lifeline", true},
		{24, "gold_lifeline", "Gold Lifeline", true},
		{25, "lifesaver", "Lifesaver", true},
		{100, "lifesaver", "Lifesaver", true},
	}
	for _, tt := range tests {
		key, label, ok := RankForCount(tt.count)
		if key != tt.key || label != tt.label || ok != tt.ok {
			t.Errorf("RankForCount(%d) = (%q,%q,%v), want (%q,%q,%v)", tt.count, key, label, ok, tt.key, tt.label, tt.ok)
		}
	}
}
