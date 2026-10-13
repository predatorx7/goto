package main

import (
	"fmt"
	"os"

	"github.com/predatorx7/goto/internal/app"
)

func main() {
	application, err := app.New()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error initializing goto: %v\n", err)
		os.Exit(1)
	}

	exitCode := application.Run(os.Args[1:])
	os.Exit(exitCode)
}
