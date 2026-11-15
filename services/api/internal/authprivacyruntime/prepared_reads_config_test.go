package authprivacyruntime

import (
	"encoding/json"
	"testing"
)

func TestPreparedReadConfigurationDefaultsAndIsolation(t *testing.T) {
	for _, test := range []struct {
		raw                   string
		feed, media, comments bool
	}{
		{`{"posts":{},"comments":{}}`, false, false, false},
		{`{"posts":{"preparedFeedReads":true},"comments":{}}`, true, false, false},
		{`{"posts":{"preparedMediaReads":true},"comments":{}}`, false, true, false},
		{`{"posts":{},"comments":{"preparedReads":true}}`, false, false, true},
	} {
		var c Config
		if err := json.Unmarshal([]byte(test.raw), &c); err != nil {
			t.Fatal(err)
		}
		if c.Posts.PreparedFeedReads != test.feed || c.Posts.PreparedMediaReads != test.media || c.Comments.PreparedReads != test.comments {
			t.Fatal("independent read switches changed defaults or shared state")
		}
	}
}
