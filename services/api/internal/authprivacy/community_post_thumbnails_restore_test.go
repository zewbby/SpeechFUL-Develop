package authprivacy

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func TestThumbnailStorageDumpRestoreIntegrityPostgres(t *testing.T) {
	f := thumbnailFixture(t)
	dump := filepath.Join(t.TempDir(), "posts.dump")
	dsn := os.Getenv("AUTHLAB_C_DSN")
	if e := exec.Command("pg_dump", "--format=custom", "--schema=c_posts", "--no-owner", "--no-privileges", "--file", dump, dsn).Run(); e != nil {
		t.Fatal("owned schema dump", e)
	}
	mustExec(t, f.l.cp, `DROP SCHEMA c_posts CASCADE`)
	if e := exec.Command("pg_restore", "--no-owner", "--no-privileges", "--dbname", dsn, dump).Run(); e != nil {
		t.Fatal("owned schema restore", e)
	}
	if e := f.l.c.checkThumbnailStorageSchema(context.Background(), false); e != nil {
		t.Fatal("restored thumbnail integrity", e)
	}
	const executeCount = `SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='c_posts' AND p.proname IN ('account_thumbnail_storage','erase_source_thumbnails')
 AND has_function_privilege('hnuhole_c_runtime',p.oid,'EXECUTE')`
	if count(t, f.l.cp, executeCount) != 2 {
		t.Fatal("fixture did not reproduce default execute after ACL-free restore")
	}
	grants, e := os.ReadFile("../../../../infra/postgres/grant-post-images.sql")
	if e != nil {
		t.Fatal(e)
	}
	mustExec(t, f.l.cp, string(grants))
	if count(t, f.l.cp, executeCount) != 0 {
		t.Fatal("restored trigger function acquired runtime execute")
	}
}
