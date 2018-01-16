package main

import (
	"crypto/tls"
	"log"
	"net"
	"net/http"
	"os"
	"strconv"

	"github.com/cloudfoundry-community/go-cfenv"
	"github.com/go-redis/redis"
)

var (
	creds map[string]interface{}
)

func handler(w http.ResponseWriter, r *http.Request) {
	client := redis.NewClient(&redis.Options{
		Addr: net.JoinHostPort(
			creds["host"].(string),
			strconv.Itoa(int(creds["port"].(float64))),
		),
		Password:  creds["password"].(string),
		TLSConfig: &tls.Config{InsecureSkipVerify: true},
	})

	_, err := client.Ping().Result()
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
	}
}

func main() {
	env, _ := cfenv.Current()
	services, _ := env.Services.WithLabel("redis")
	if len(services) != 1 {
		log.Fatal("redis service not found")
	}
	creds = services[0].Credentials

	http.HandleFunc("/", handler)
	log.Fatal(http.ListenAndServe(net.JoinHostPort("", os.Getenv("PORT")), nil))
}
