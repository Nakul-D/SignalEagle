package config

import (
	"fmt"
	"os"
	"strconv"
)

type Config struct {
	Stage               string // "dev", "test", "prod"
	AwsRegion           string
	AwsAccessKeyID      string // Don't set in prod, will be inferred from IAM
	AwsSecretAccessKey  string // Don't set in prod, will be inferred from IAM
	DbHost              string
	DbUser              string
	DbPassword          string
	DbName              string
	DbPort              string
	DbSslMode           string
	JwtSecretKey        string
	TokenExpiresInHours int
}

func LoadConfig() (*Config, error) {

	var cfg Config
	var ok bool

	if cfg.Stage, ok = os.LookupEnv("STAGE"); !ok {
		return nil, fmt.Errorf("missing STAGE")
	}

	if cfg.AwsRegion, ok = os.LookupEnv("AWS_REGION"); !ok {
		return nil, fmt.Errorf("missing AWS_REGION")
	}

	// Prod: leave blank so that AWS SDK can pick these up from IAM role automatically
	if cfg.Stage == "dev" || cfg.Stage == "test" {
		if cfg.AwsAccessKeyID, ok = os.LookupEnv("AWS_ACCESS_KEY_ID"); !ok {
			return nil, fmt.Errorf("missing AWS_ACCESS_KEY_ID")
		}
		if cfg.AwsSecretAccessKey, ok = os.LookupEnv("AWS_SECRET_ACCESS_KEY"); !ok {
			return nil, fmt.Errorf("missing AWS_SECRET_ACCESS_KEY")
		}
	}

	if cfg.DbHost, ok = os.LookupEnv("DB_HOST"); !ok {
		return nil, fmt.Errorf("missing DB_HOST")
	}

	if cfg.DbUser, ok = os.LookupEnv("DB_USER"); !ok {
		return nil, fmt.Errorf("missing DB_USER")
	}

	if cfg.DbPassword, ok = os.LookupEnv("DB_PASSWORD"); !ok {
		return nil, fmt.Errorf("missing DB_PASSWORD")
	}

	if cfg.DbName, ok = os.LookupEnv("DB_NAME"); !ok {
		return nil, fmt.Errorf("missing DB_NAME")
	}

	if cfg.DbPort, ok = os.LookupEnv("DB_PORT"); !ok {
		return nil, fmt.Errorf("missing DB_PORT")
	}

	if cfg.DbSslMode, ok = os.LookupEnv("DB_SSLMODE"); !ok {
		return nil, fmt.Errorf("missing DB_SSLMODE")
	}

	if cfg.JwtSecretKey, ok = os.LookupEnv("JWT_SECRET_KEY"); !ok {
		return nil, fmt.Errorf("missing JWT_SECRET_KEY")
	}

	var expiresStr string
	var err error
	expiresStr, ok = os.LookupEnv("TOKEN_EXPIRES_IN_HOURS")
	if !ok {
		return nil, fmt.Errorf("missing TOKEN_EXPIRES_IN_HOURS")
	}
	cfg.TokenExpiresInHours, err = strconv.Atoi(expiresStr)
	if err != nil {
		return nil, fmt.Errorf("error converting string to int")
	}

	return &cfg, nil
}
