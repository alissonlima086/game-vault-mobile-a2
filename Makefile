SHELL := bash
PORT ?= 3000
PID_FILE := .flutter_web.pid
LOG_FILE := .flutter_web.log

# Detecta automaticamente se o comando flutter já está no PATH
# Se estiver fora do nix develop, delega automaticamente para "nix develop -c"
IN_NIX := $(shell command -v flutter >/dev/null 2>&1 && echo "yes" || echo "no")
ifeq ($(IN_NIX),yes)
  EXEC :=
else
  EXEC := nix develop -c
endif

.PHONY: help up down status logs dev run-android test check analyze build-web build-apk clean

# Ajuda padrão com a lista de comandos
help:
	@echo "================================================================="
	@echo "ZVault - Biblioteca de Jogos"
	@echo "================================================================="
	@echo "Comandos principais:"
	@echo "  make up          Inicia o servidor Flutter Web (porta $(PORT)) em background"
	@echo "  make down        Encerra o servidor Flutter Web e libera a porta $(PORT)"
	@echo "  make status      Verifica se a aplicação está em execução"
	@echo "  make logs        Acompanha os logs do servidor Web em tempo real"
	@echo "  make dev         Executa o Flutter Web interativamente no terminal (foreground)"
	@echo "  make run-android Executa o aplicativo no celular Android conectado (via ADB)"
	@echo ""
	@echo "Qualidade e Compilação:"
	@echo "  make test        Executa toda a suíte de testes unitários e de widgets"
	@echo "  make check       Executa a análise estática (flutter analyze)"
	@echo "  make build-web   Compila a versão para Web em build/web"
	@echo "  make build-apk   Compila o APK Android (Debug)"
	@echo "  make clean       Limpa artefatos de build e arquivos temporários"
	@echo "================================================================="

# Inicia a aplicação Web na porta 3000 em background
up:
	@if [ -f $(PID_FILE) ] && kill -0 $$(cat $(PID_FILE)) 2>/dev/null; then \
		echo "[AVISO] A aplicação já está em execução (PID: $$(cat $(PID_FILE))) em http://localhost:$(PORT)"; \
	else \
		echo "Iniciando Flutter Web na porta $(PORT) em background..."; \
		> $(LOG_FILE); \
		nohup $(EXEC) flutter run -d web-server --web-port=$(PORT) --web-hostname=localhost < /dev/null > $(LOG_FILE) 2>&1 & \
		PID=$$!; \
		echo $$PID > $(PID_FILE); \
		echo "Compilando e aguardando servidor inicializar..."; \
		for i in {1..35}; do \
			if grep -q "http://localhost:$(PORT)" $(LOG_FILE) 2>/dev/null; then \
				break; \
			fi; \
			if ! kill -0 $$PID 2>/dev/null; then \
				echo "[ERRO] O processo encerrou inesperadamente. Verifique os logs em $(LOG_FILE):"; \
				cat $(LOG_FILE); \
				rm -f $(PID_FILE); \
				exit 1; \
			fi; \
			sleep 1; \
		done; \
		echo "Aplicação iniciada com sucesso!"; \
		echo "Acesse no seu navegador: http://localhost:$(PORT)"; \
		echo "Para acompanhar os logs: make logs"; \
		echo "Para parar a aplicação:  make down"; \
	fi

# Para o servidor Web e libera a porta
down:
	@echo "Encerrando aplicação Flutter Web..."
	@if [ -f $(PID_FILE) ]; then \
		PID=$$(cat $(PID_FILE) 2>/dev/null); \
		if [ -n "$$PID" ] && [ "$$PID" -gt 1 ] 2>/dev/null; then \
			if kill -0 "$$PID" 2>/dev/null; then \
				kill "$$PID" 2>/dev/null || true; \
				sleep 1; \
				if kill -0 "$$PID" 2>/dev/null; then \
					kill -9 "$$PID" 2>/dev/null || true; \
				fi; \
				echo "Processo $$PID finalizado."; \
			fi; \
		fi; \
		rm -f $(PID_FILE); \
	fi
	@pkill -f "[f]lutter.*web-server" 2>/dev/null || true
	@pkill -f "[f]lutter_tools.*web-server" 2>/dev/null || true
	@echo "Aplicação finalizada. Porta $(PORT) liberada."

# Verifica status do processo
status:
	@if [ -f $(PID_FILE) ] && kill -0 $$(cat $(PID_FILE)) 2>/dev/null; then \
		echo "Aplicação ATIVA (PID: $$(cat $(PID_FILE))) - http://localhost:$(PORT)"; \
	else \
		echo "Aplicação PARADA."; \
	fi

# Acompanha logs do servidor
logs:
	@if [ -f $(LOG_FILE) ]; then \
		tail -f $(LOG_FILE); \
	else \
		echo "Nenhum arquivo de log encontrado. Inicie o servidor com 'make up'."; \
	fi

# Executa em primeiro plano (foreground com hot-reload interativo)
dev:
	@echo "Iniciando Flutter Web em primeiro plano (pressione 'r' para hot-reload ou 'q' para sair)..."
	$(EXEC) flutter run -d web-server --web-port=$(PORT) --web-hostname=localhost

# Executa em dispositivo Android conectado
run-android:
	@echo "Iniciando no dispositivo Android conectado via ADB..."
	$(EXEC) flutter run

# Executa os testes automatizados
test:
	@echo "Executando testes automatizados..."
	$(EXEC) flutter test

# Executa análise estática
check analyze:
	@echo "Executando análise estática de código..."
	$(EXEC) flutter analyze

# Compila para Web
build-web:
	@echo "Compilando Flutter Web..."
	$(EXEC) flutter build web

# Compila para Android
build-apk:
	@echo "Compilando Android APK (Debug)..."
	$(EXEC) flutter build apk --debug

# Deploy da Edge Function no Supabase Cloud
deploy-functions:
	@echo "Fazendo deploy da Edge Function igdb-proxy no Supabase Cloud..."
	$(EXEC) supabase functions deploy igdb-proxy --project-ref uvfkktpzdichkdrmazjl --no-verify-jwt

# Limpeza completa
clean:
	@echo "Limpando artefatos..."
	@$(MAKE) down >/dev/null 2>&1 || true
	$(EXEC) flutter clean
	@rm -f $(PID_FILE) $(LOG_FILE)
	@echo "Limpeza concluída."
