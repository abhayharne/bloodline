package matching

import "testing"

// TestCompatibleForComponentPlasma covers the "reverse ABO" table literally:
// patient <- acceptable donor groups, Rh ignored. O is the universal recipient,
// AB patients may only receive AB plasma.
func TestCompatibleForComponentPlasma(t *testing.T) {
	groups := []string{"O-", "O+", "A-", "A+", "B-", "B+", "AB-", "AB+"}
	acceptableABO := map[string]map[string]bool{
		"O":  {"O": true, "A": true, "B": true, "AB": true},
		"A":  {"A": true, "AB": true},
		"B":  {"B": true, "AB": true},
		"AB": {"AB": true},
	}
	for _, component := range []string{ComponentPlasma, ComponentCryo} {
		for _, patient := range groups {
			for _, donor := range groups {
				want := acceptableABO[aboLetter(patient)][aboLetter(donor)]
				if got := CompatibleForComponent(patient, donor, component); got != want {
					t.Errorf("CompatibleForComponent(%q, %q, %q) = %v, want %v",
						patient, donor, component, got, want)
				}
			}
		}
	}
}

// TestCompatibleForComponentRedCells distinguishes the red-cell chart from
// exact matching for whole blood and other.
func TestCompatibleForComponentRedCells(t *testing.T) {
	tests := []struct {
		patient, donor, component string
		want                      bool
	}{
		{"O-", "O-", ComponentWholeBlood, true},
		{"O-", "AB+", ComponentRedCells, false},
		{"O+", "O-", ComponentWholeBlood, false},
		{"AB+", "AB+", ComponentOther, true},
		{"AB+", "O-", ComponentOther, false},
		{" a+ ", "o-", ComponentRedCells, true},
		{"O+", "Z+", ComponentWholeBlood, false},
	}
	for _, tc := range tests {
		if got := CompatibleForComponent(tc.patient, tc.donor, tc.component); got != tc.want {
			t.Errorf("CompatibleForComponent(%q, %q, %q) = %v, want %v",
				tc.patient, tc.donor, tc.component, got, tc.want)
		}
	}
}

// TestPlateletRanking verifies same-ABO is preferred and Rh-negative patients
// get Rh-negative donors first; any valid group is still acceptable (ranked,
// not excluded).
func TestPlateletRanking(t *testing.T) {
	tests := []struct {
		name           string
		patient, donor string
		wantCompat     bool
		wantRank       int
	}{
		{"same group", "O+", "O+", true, 0},
		{"same ABO different Rh, positive patient", "A+", "A-", true, 0},
		{"negative patient gets negative donor first", "O-", "O-", true, 0},
		{"negative patient with positive donor ranked down", "O-", "O+", true, 1},
		{"other ABO acceptable, ranked below", "O+", "AB+", true, 2},
		{"other ABO with negative patient and positive donor", "O-", "AB+", true, 3},
		{"invalid group not compatible", "O+", "Z+", false, -1},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := CompatibleForComponent(tc.patient, tc.donor, ComponentPlatelets); got != tc.wantCompat {
				t.Errorf("Compatible = %v, want %v", got, tc.wantCompat)
			}
			if got := DonorRankForComponent(tc.patient, tc.donor, ComponentPlatelets); got != tc.wantRank {
				t.Errorf("DonorRank = %d, want %d", got, tc.wantRank)
			}
		})
	}
}

// TestCompatibleGroupsOrdersByRank checks the group list handed to the store
// for apheresis components is best-first.
func TestCompatibleGroupsOrdersByRank(t *testing.T) {
	// Plasma: O patient can receive from every group; same ABO (O) ranks first.
	got := CompatibleGroups("O-", ComponentPlasma)
	if len(got) != 8 {
		t.Fatalf("plasma groups for O- = %v, want all 8", got)
	}
	if got[0] != "O-" || got[1] != "O+" {
		t.Fatalf("plasma groups for O- = %v, want O groups first", got)
	}

	// AB patient may only receive AB plasma; exact group ranks first.
	got = CompatibleGroups("AB+", ComponentCryo)
	if len(got) != 2 || got[0] != "AB+" || got[1] != "AB-" {
		t.Fatalf("cryo groups for AB+ = %v, want [AB+ AB-]", got)
	}

	// Platelets keep every group but rank same-ABO negative first for O-.
	got = CompatibleGroups("O-", ComponentPlatelets)
	if len(got) != 8 || got[0] != "O-" {
		t.Fatalf("platelet groups for O- = %v, want O- first", got)
	}
}
