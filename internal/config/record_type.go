// ==============================================================================
// MasterDnsVPN
// Author: MasterkinG32
// Github: https://github.com/masterking32
// Year: 2026
// ==============================================================================
// Shared helper for parsing the DNS_RECORD_TYPE config knob into a qtype enum
// value. Used by both the client (selects the qtype of outbound tunnel queries)
// and the install/setup flow (validates user input).
// ==============================================================================

package config

import (
	"fmt"
	"strings"

	Enums "masterdnsvpn-go/internal/enums"
)

// ResolveDNSRecordType maps a user-facing record-type string ("TXT", "NULL",
// "CNAME", "A", "AAAA") to its qtype enum value. The second return value is
// true when the transport layer fully supports that record type end-to-end;
// when false, callers should treat the value as a request to downgrade to TXT
// and log a warning.
func ResolveDNSRecordType(s string) (qtype uint16, nativelySupported bool, err error) {
	switch strings.ToUpper(strings.TrimSpace(s)) {
	case "", "TXT":
		return Enums.DNS_RECORD_TYPE_TXT, true, nil
	case "NULL":
		return Enums.DNS_RECORD_TYPE_NULL, true, nil
	case "CNAME":
		return Enums.DNS_RECORD_TYPE_CNAME, false, nil
	case "A":
		return Enums.DNS_RECORD_TYPE_A, false, nil
	case "AAAA":
		return Enums.DNS_RECORD_TYPE_AAAA, false, nil
	default:
		return 0, false, fmt.Errorf("invalid DNS_RECORD_TYPE: %q (expected TXT, NULL, CNAME, A, or AAAA)", s)
	}
}
