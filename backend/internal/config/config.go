package config

import (
	"os"
)

type Config struct {
	Port         string
	DatabasePath string
	APIKey       string
	// GoCardless
	GoCardlessSecretID  string
	GoCardlessSecretKey string
	GoCardlessBaseURL   string
}

func Load() *Config {
	return &Config{
		Port:                getEnv("PORT", "8082"),
		DatabasePath:        getEnv("DATABASE_PATH", "./diruzorro.db"),
		APIKey:              getEnv("API_KEY", ""),
		GoCardlessSecretID:  getEnv("GOCARDLESS_SECRET_ID", ""),
		GoCardlessSecretKey: getEnv("GOCARDLESS_SECRET_KEY", ""),
		GoCardlessBaseURL:   getEnv("GOCARDLESS_BASE_URL", "https://bankaccountdata.gocardless.com/api/v2"),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
