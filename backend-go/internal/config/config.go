package config

import "os"

type Config struct {
	Port        string
	DatabaseURL string
}

func Load() Config {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		// Local default for development.
		dsn = "postgres://postgres:postgres@localhost:5432/tea_store?sslmode=disable"
	}
	return Config{
		Port:        port,
		DatabaseURL: dsn,
	}
}
