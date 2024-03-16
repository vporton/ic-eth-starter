#!/usr/bin/make -f

.PHONY: all
all: frontend

.PHONY: backend
backend: CanDBPartition.wasm
	dfx deploy backend
	dfx generate backend
	env -i scripts/read-env.sh
	-dfx canister call CanDBIndex init '(vec {})'

.PHONY: frontend
frontend: backend
	cd frontend && npm i && npm run build
	dfx deploy frontend

.PHONY: CanDBPartition.wasm
CanDBPartition.wasm:
	moc `mops sources` src/backend/CanDBPartition.mo
