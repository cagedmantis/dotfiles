// Behavioural tests for the dotfiles in the parent directory.
//
// Kept as its own module so the dotfiles repo itself needs no go.mod, and so
// `go test ./...` here never reaches outside tests/.
module dotfiles/tests

go 1.24
