package start

import (
	"log/slog"
	"os"

	"github.com/Nakul-D/SignalEagle/config"
	"github.com/Nakul-D/SignalEagle/database/rds"
	"github.com/gofiber/fiber/v3"
	"gorm.io/gorm"
)

/*
Loading environment variables and connecting to database is separated from setting up the fiber app
This is done to make automated testing possible
*/

func Server() *fiber.App {

	// Loading config
	cfg, err := config.LoadConfig()
	if err != nil {
		slog.Error("failed to load environment variables", "error", err)
		os.Exit(1)
	}

	// Connecting to database
	rdsDB, err := rds.ConnectToRds(cfg.RdsHost, cfg.RdsUser, cfg.RdsPassword, cfg.RdsName, cfg.RdsPort, cfg.RdsSslMode)
	if err != nil {
		slog.Error("failed to connect to RDS", "error", err)
		os.Exit(1)
	}

	return BuildApp(*cfg, rdsDB)
}

func BuildApp(cfg config.Config, rdsDB *gorm.DB) *fiber.App {

	app := fiber.New()

	app.Get("/", func(c fiber.Ctx) error {
		return c.JSON(fiber.Map{"msg": "Welcome to SignalEagle API!"})
	})

	app.Get("/test", func(c fiber.Ctx) error {
		return c.JSON(fiber.Map{"msg": "The server is running :)"})
	})

	return app
}
