// Copyright 2016 IBM Corporation
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.

package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
)

var Details = map[string]string{
	"paperback": "200 pages",
	"publisher": "PublisherA",
	"language":  "English",
	"isbn_10":   "1234567890",
	"isbn_13":   "123-1234567980",
}

func main() {
	if len(os.Args) < 2 {
		log.Printf("Usage: %s <port>", os.Args[0])
		os.Exit(-1)
	}

	port := os.Args[1]

	http.HandleFunc("/details", detailsHandler)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func detailsHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	bytes, _ := json.Marshal(Details)
	w.Write(bytes)
}
