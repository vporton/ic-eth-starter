#!/usr/bin/make -f

.PHONY: all
all: frontend

.PHONY: backend
backend:
	dfx deploy backend
	dfx generate backend
	env -i scripts/read-env.sh

.PHONY: frontend
frontend: backend
	cd frontend && npm i && npm run build
	dfx deploy frontend