package main

import (
	"fmt"
	"log"
	"net/http"
)

type Expense struct {
	id           int32
	description  string
	expense_type string
	value        int32
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/", homeHandler)
	server := &http.Server{
		Addr:    ":8080",
		Handler: mux,
	}
	fmt.Println("Server starting...")
	if err := server.ListenAndServe(); err != nil {
		log.Fatal("Server failed to start:", err)
	}
}

func homeHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	fmt.Println("Hello, World!")
}
