package version

var (
	version = "edge"
	commit  string
)

// Version return the version of api-go
func Version() string {
	return version
}

// Commit returns the gitz commit SHA for the code that api-go was built from
func Commit() string {
	return commit
}
