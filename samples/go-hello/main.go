// Minimal Go hello-world for the TruStacks workshop quickstart.
// The Code Reviewer agent fingerprints this repo as a Go service;
// the DevOps Engineer emits CI + Helm + ArgoCD against it on /plan.
package main

import (
	"fmt"
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "hello from TruStacks quickstart")
	})
	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "ok")
	})
	log.Println("listening on :8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal(err)
	}
}
