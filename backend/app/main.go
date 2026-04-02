package main

import (
	"log/slog"
	"os"

	"github.com/Nakul-D/SignalEagle/start"
)

func main() {

	// Global setting for logging
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

	// Starting server
	server := start.Server()
	err := server.Listen(":3000")
	if err != nil {
		slog.Error("failed to start server", "error", err)
		os.Exit(1)
	}
}
