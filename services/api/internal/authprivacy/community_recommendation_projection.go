package authprivacy

import (
	"context"
	"slices"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/zhubaozhenshuai666-lang/HnuHole/services/api/internal/posts"
	rm "github.com/zhubaozhenshuai666-lang/HnuHole/services/api/internal/recommendation/roundmodel"
)

// Use the current Feed projection inside the final authorized transaction.
// Missing or newly filtered slots stay omitted without changing the manifest.
// hiddenPosts mirrors the Feed's optional extension. An account hide also
// advances the private filter revision, so a stale round normally fails closed;
// this final projection still applies the viewer's current choice instead of
// relying on that coupling alone.
type recommendationFeedProjection struct {
	hiddenPosts bool
}

func (p recommendationFeedProjection) ProjectRecommendation(ctx context.Context, tx pgx.Tx, s RecommendationScope, ids []rm.ID) (RecommendationProjection, error) {
	out := RecommendationProjection{Items: []posts.FeedPost{}, Unavailable: []int{}}
	account, err := uuid.Parse(string(s.Binding.Account))
	if err != nil || account == uuid.Nil || len(ids) > 10 {
		return RecommendationProjection{}, errRecommendationProjection
	}
	position := make(map[string]int, len(ids))
	keys := recommendationIDs(ids)
	for i, id := range ids {
		key := string(id)
		parsed, err := posts.ParseResourceID(key)
		if _, exists := position[key]; err != nil || parsed.String() != key || exists {
			return RecommendationProjection{}, errRecommendationProjection
		}
		position[key] = i
	}
	hidden := map[string]bool{}
	if p.hiddenPosts && len(keys) > 0 {
		rows, err := tx.Query(ctx, `SELECT post_id::text FROM c_posts.hidden_posts WHERE account_id=$1 AND post_id=ANY($2::uuid[]) AND hidden`, account, keys)
		if err != nil {
			return RecommendationProjection{}, err
		}
		for rows.Next() {
			var key string
			if err = rows.Scan(&key); err != nil {
				break
			}
			hidden[key] = true
		}
		if err == nil {
			err = rows.Err()
		}
		rows.Close()
		if err != nil {
			return RecommendationProjection{}, err
		}
	}
	rows, err := readPublicListProjection(ctx, tx, account, keys,
		PostQuery{Kind: PostFeed, ImageSizes: true}, nil, true, true)
	if err != nil {
		return RecommendationProjection{}, err
	}
	var visible [10]bool
	last := -1
	for _, row := range rows {
		i, ok := position[row.post.PostID]
		if !ok || i <= last {
			return RecommendationProjection{}, errRecommendationProjection
		}
		last = i
		if hidden[row.post.PostID] {
			continue
		}
		if slices.Contains(s.Channels, row.post.ChannelID) {
			visible[i] = true
			out.Items = append(out.Items, row.post)
		}
	}
	for i := range ids {
		if !visible[i] {
			out.Unavailable = append(out.Unavailable, i)
		}
	}
	return out, nil
}
