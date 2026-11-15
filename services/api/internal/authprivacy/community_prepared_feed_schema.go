package authprivacy

import "context"

// These switches remain fail-closed until the complete 0041 shape, source
// hooks and least-privilege checks are installed in the next Base slice.
func (c *Community) checkPreparedFeedReadSchema(context.Context) error {
	return errPostSchema
}

func (c *Community) checkPreparedMediaReadSchema(context.Context) error {
	return errPostSchema
}
