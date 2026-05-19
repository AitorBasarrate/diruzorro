# Diruzorro 💰

App de finanzas personales. Monorepo con backend en Go y app móvil en Flutter.

## Estructura

```
diruzorro/
├── backend/          # API REST en Go (Chi + SQLite)
├── mobile/           # App Flutter (Riverpod + fl_chart)
├── api/              # Especificación OpenAPI 3.0
├── deployments/      # Docker Compose + configuración
├── scripts/          # Scripts de automatización
└── Taskfile.yaml     # Orquestación de tareas
```

## Requisitos

- **Go** 1.25+
- **Flutter** 3.x+
- **Docker** y Docker Compose (para despliegue)
- **Task** ([go-task.dev](https://taskfile.dev)) para orquestación

## Inicio rápido

```bash
# 1. Instalar Task (si no lo tienes)
go install github.com/go-task/task/v3/cmd/task@latest

# 2. Configuración inicial
task setup

# 3. Editar deployments/.env con tus claves

# 4. Ejecutar el backend en desarrollo
task backend:run

# 5. Ejecutar la app Flutter
task mobile:run
```

## Comandos disponibles

| Comando | Descripción |
|---------|-------------|
| `task backend:run` | Ejecutar backend en dev |
| `task backend:build` | Compilar backend |
| `task backend:test` | Tests del backend |
| `task backend:lint` | Lint del backend |
| `task mobile:run` | Ejecutar app Flutter |
| `task mobile:build:apk` | Compilar APK release |
| `task mobile:test` | Tests de Flutter |
| `task mobile:lint` | Análisis de Flutter |
| `task test` | Todos los tests |
| `task lint` | Lint completo |
| `task docker:up` | Levantar Docker |
| `task docker:down` | Parar Docker |

## API

La API REST está documentada en `api/openapi.yaml`. Endpoints principales:

- `GET/POST /api/v1/accounts` — Cuentas
- `GET/POST /api/v1/categories` — Categorías
- `GET/POST /api/v1/transactions` — Transacciones
- `GET/POST /api/v1/budgets` — Presupuestos
- `GET/POST /api/v1/savings-goals` — Objetivos de ahorro
- `GET /api/v1/reports/*` — Informes

Autenticación: header `X-API-Key` con la clave configurada en `.env`.

## Stack

| Componente | Tecnología |
|-----------|-----------|
| Backend HTTP | Go + Chi v5 |
| Base de datos | SQLite (modernc.org/sqlite) |
| App móvil | Flutter + Riverpod |
| Gráficos | fl_chart |
| Open Banking | GoCardless Bank Account Data (PSD2) |
| Contenedores | Docker + Docker Compose |

## Licencia

Proyecto privado.
