package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/azuredevcollege/aks/dapr-secrets-add-pod-identity/src/api-go/pkg/http"
)

func main() {
	fmt.Println("Application started.")

	api := http.NewAPI()
	api.StartNonBlocking()

	fmt.Println("Server started.")

	// Receive a signal to stop app
	c := make(chan os.Signal, 1)
	signal.Notify(c, syscall.SIGINT, syscall.SIGTERM, os.Interrupt)

	// block until we receive our signal
	<-c

	fmt.Println("Execution stopped.")
	os.Exit(0)
}
