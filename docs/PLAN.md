# Diruzorro — Plan del Proyecto

## 1. Visión General

**Diruzorro** es una aplicación de finanzas personales compuesta por:
- Un **backend API** en Go que gestiona datos y se conecta a la banca abierta
- Una **app móvil** en Flutter para Android/iOS

El objetivo es tener control total sobre tus finanzas: gastos, ingresos, presupuestos, ahorro y sincronización automática con tu banco.

---

## 2. Funcionalidades

### Fase 1 — Core
- **Seguimiento de gastos**: registrar gastos con categoría, cuenta, importe, fecha y descripción
- **Seguimiento de ingresos**: registrar ingresos de diferentes fuentes
- **Gestión de cuentas**: múltiples cuentas (corriente, ahorro, tarjeta crédito)
- **Categorías personalizables**: con icono, color y límite de presupuesto

### Fase 2 — Presupuestos y Ahorro
- **Presupuestos mensuales**: límite por categoría, alerta al superar
- **Objetivos de ahorro**: meta económica con fecha objetivo y progreso visual

### Fase 3 — Informes
- **Gastos por categoría**: gráfico circular (pie chart)
- **Balance mensual**: ingresos vs gastos por mes (bar chart)
- **Tendencias**: evolución del gasto en los últimos N meses (line chart)

### Fase 4 — Banca Abierta (PSD2)
- **Conexión con banco**: vincular cuentas de bancos españoles
- **Importación automática**: sincronizar transacciones desde el banco
- **Categorización asistida**: sugerir categoría para transacciones importadas

---

## 3. Arquitectura

```
┌─────────────────┐         ┌──────────────────┐
│   Flutter App   │ ──────▶ │   Go API (Chi)   │
│   (Riverpod)    │  REST   │   Puerto 8080    │
└─────────────────┘         └────────┬─────────┘
                                     │
                            ┌────────▼─────────┐
                            │     SQLite DB    │
                            │  (fichero local) │
                            └──────────────────┘
                                     │
                            ┌────────▼─────────┐
                            │   GoCardless     │
                            │   PSD2 API       │
                            └──────────────────┘
```

### Flujo de datos
1. La app Flutter hace peticiones REST al backend Go
2. El backend lee/escribe en SQLite
3. Para banca abierta, el backend actúa como proxy hacia GoCardless
4. Las transacciones importadas se almacenan en la misma tabla de transacciones

---

## 4. Stack Tecnológico

### Backend (Go)
| Componente | Librería | Justificación |
|-----------|----------|---------------|
| Router HTTP | chi/v5 | Ligero, compatible con net/http stdlib |
| Base de datos | SQLite (modernc.org/sqlite) | Pure Go, sin CGO, ideal para un usuario |
| Configuración | Variables de entorno | Sencillo, 12-factor app |
| Logging | log/slog (stdlib) | Structured logging nativo desde Go 1.21 |
| Testing | testing + testify | Stdlib + assertions cómodas |
| Open Banking | GoCardless Bank Account Data | Cubre bancos españoles, tier gratuito |

### Mobile (Flutter)
| Componente | Librería | Justificación |
|-----------|----------|---------------|
| Estado | flutter_riverpod | Reactivo, type-safe, escalable |
| HTTP | dio | Interceptores, timeout, retry |
| Navegación | go_router | Declarativa, deep linking |
| Gráficos | fl_chart | Ligera, customizable, bien mantenida |
| Caché local | sqflite | SQLite nativo en el dispositivo |
| i18n | intl + flutter_localizations | Soporte español nativo |

### Infraestructura
| Componente | Tecnología |
|-----------|-----------|
| Contenedor | Docker (multi-stage build) |
| Orquestación | Docker Compose |
| Automatización | Taskfile (go-task) |
| CI/CD | GitHub Actions |

---

## 5. Modelo de Datos

### accounts
| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | INTEGER PK | Identificador |
| name | TEXT | Nombre (ej: "Cuenta BBVA") |
| type | TEXT | checking / savings / credit |
| currency | TEXT | EUR por defecto |
| balance | REAL | Saldo actual |
| bank_id | TEXT | ID externo del banco (si está vinculada) |
| created_at | DATETIME | Fecha de creación |

### categories
| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | INTEGER PK | Identificador |
| name | TEXT | Nombre (ej: "Alimentación") |
| type | TEXT | expense / income |
| icon | TEXT | Emoji del icono |
| color | TEXT | Color hex (#FF5733) |
| budget_limit | REAL | Límite mensual (0 = sin límite) |

### transactions
| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | INTEGER PK | Identificador |
| account_id | INTEGER FK | Cuenta asociada |
| category_id | INTEGER FK | Categoría (nullable) |
| amount | REAL | Importe |
| type | TEXT | expense / income / transfer |
| description | TEXT | Descripción/concepto |
| date | TEXT | Fecha (YYYY-MM-DD) |
| bank_transaction_id | TEXT | ID del banco (si importada) |
| created_at | DATETIME | Fecha de registro |

### budgets
| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | INTEGER PK | Identificador |
| category_id | INTEGER FK | Categoría |
| month | INTEGER | Mes (1-12) |
| year | INTEGER | Año |
| limit_amount | REAL | Presupuesto máximo |
| spent_amount | REAL | Gastado hasta ahora |

### savings_goals
| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | INTEGER PK | Identificador |
| name | TEXT | Nombre del objetivo |
| target_amount | REAL | Meta económica |
| current_amount | REAL | Progreso actual |
| target_date | TEXT | Fecha objetivo (nullable) |
| created_at | DATETIME | Fecha de creación |

### bank_connections
| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | INTEGER PK | Identificador |
| institution_id | TEXT | ID del banco en GoCardless |
| requisition_id | TEXT | ID de la requisición PSD2 |
| status | TEXT | pending / active / expired |
| last_sync | DATETIME | Última sincronización |
| created_at | DATETIME | Fecha de creación |

---

## 6. API REST

Base URL: `http://localhost:8080/api/v1`

Autenticación: `X-API-Key: <tu-clave>` en cada petición.

### Endpoints

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | /accounts | Listar cuentas |
| POST | /accounts | Crear cuenta |
| PUT | /accounts/:id | Actualizar cuenta |
| DELETE | /accounts/:id | Eliminar cuenta |
| GET | /categories | Listar categorías |
| POST | /categories | Crear categoría |
| PUT | /categories/:id | Actualizar categoría |
| DELETE | /categories/:id | Eliminar categoría |
| GET | /transactions | Listar (filtros: from, to, category_id, account_id, type) |
| POST | /transactions | Crear transacción |
| PUT | /transactions/:id | Actualizar transacción |
| DELETE | /transactions/:id | Eliminar transacción |
| GET | /budgets | Listar presupuestos (filtros: month, year) |
| POST | /budgets | Crear presupuesto |
| PUT | /budgets/:id | Actualizar presupuesto |
| GET | /savings-goals | Listar objetivos |
| POST | /savings-goals | Crear objetivo |
| PUT | /savings-goals/:id | Actualizar objetivo |
| DELETE | /savings-goals/:id | Eliminar objetivo |
| GET | /reports/expenses-by-category | Gastos por categoría (from, to) |
| GET | /reports/monthly-balance | Balance mensual (year) |
| GET | /reports/trends | Tendencia de gastos (months) |
| GET | /banking/institutions | Listar bancos disponibles |
| POST | /banking/connect | Iniciar conexión bancaria |
| GET | /banking/callback | Callback post-autorización |
| POST | /banking/sync | Sincronizar transacciones |
| DELETE | /banking/connections/:id | Eliminar conexión |

Especificación completa: `api/openapi.yaml`

---

## 7. Integración Bancaria (PSD2)

### Proveedor: GoCardless Bank Account Data (ex-Nordigen)

**¿Por qué?**
- Cubre bancos españoles (BBVA, Santander, CaixaBank, Sabadell, etc.)
- Tiene tier gratuito para uso personal/desarrollo
- API REST bien documentada
- Cumple con regulación PSD2 europea

### Flujo de conexión
1. Usuario selecciona su banco en la app
2. Backend crea una "requisición" en GoCardless
3. Usuario es redirigido al login de su banco (en WebView o navegador)
4. El banco valida credenciales + 2FA
5. GoCardless recibe la autorización y notifica al callback
6. Backend marca la conexión como activa
7. A partir de ahí, se pueden consultar transacciones y saldos

### Limitaciones
- **Re-autenticación cada 90 días** (requisito PSD2)
- **Datos históricos**: generalmente los últimos 90 días de transacciones
- **Rate limiting**: respetar los límites de la API

### Registro
1. Crear cuenta en https://bankaccountdata.gocardless.com/
2. Crear credenciales de API (secret_id + secret_key)
3. En desarrollo, usar el modo sandbox (sin banco real)

---

## 8. Despliegue

### Docker
```bash
# Construir y levantar
cd deployments
cp .env.example .env
# Editar .env con tus valores
docker compose up -d --build
```

El backend se despliega como un contenedor Alpine mínimo (~15MB) con la base de datos SQLite en un volumen persistente.

### Requisitos del servidor
- Docker + Docker Compose
- 256MB RAM mínimo
- Puerto 8080 expuesto (o usar reverse proxy)

---

## 9. Seguridad

- **API Key**: protege todos los endpoints (excepto /health y banking callback)
- **HTTPS**: usar un reverse proxy (Caddy/Nginx) con certificado TLS
- **SQLite WAL mode**: evita corrupción en escrituras concurrentes
- **Foreign keys**: activadas para integridad referencial
- **Input validation**: en cada handler antes de procesar
- **No se almacenan credenciales bancarias**: solo tokens de GoCardless

---

## 10. Cronograma

| Semana | Fase | Entregable |
|--------|------|-----------|
| 1-2 | Infraestructura | Monorepo, backend funcional, Flutter scaffold, Docker |
| 3-4 | CRUD | Transacciones, cuentas, categorías E2E |
| 5 | Presupuestos | Presupuestos + objetivos de ahorro |
| 6 | Informes | Gráficos con fl_chart |
| 7-8 | PSD2 | Conexión bancaria + importación |
| 9 | Pulido | Errores, UX, deploy producción |
