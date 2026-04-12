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
	RdsHost             string
	RdsUser             string
	RdsPassword         string
	RdsName             string
	RdsPort             string
	RdsSslMode          string
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

	if cfg.RdsHost, ok = os.LookupEnv("RDS_HOST"); !ok {
		return nil, fmt.Errorf("missing RDS_HOST")
	}

	if cfg.RdsUser, ok = os.LookupEnv("RDS_USER"); !ok {
		return nil, fmt.Errorf("missing RDS_USER")
	}

	if cfg.RdsPassword, ok = os.LookupEnv("RDS_PASSWORD"); !ok {
		return nil, fmt.Errorf("missing RDS_PASSWORD")
	}

	if cfg.RdsName, ok = os.LookupEnv("RDS_NAME"); !ok {
		return nil, fmt.Errorf("missing RDS_NAME")
	}

	if cfg.RdsPort, ok = os.LookupEnv("RDS_PORT"); !ok {
		return nil, fmt.Errorf("missing RDS_PORT")
	}

	if cfg.RdsSslMode, ok = os.LookupEnv("RDS_SSL_MODE"); !ok {
		return nil, fmt.Errorf("missing RDS_SSL_MODE")
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
