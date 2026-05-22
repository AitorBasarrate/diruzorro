# Diruzorro — Tareas Paso a Paso

Lista detallada de tareas para completar el proyecto. Marca cada tarea con ✅ cuando la termines.

---

## Fase 1: Infraestructura (Semana 1-2)

### 1.1 Entorno de desarrollo
- [x] Instalar Go 1.25+ (`go version`)
- [x] Instalar Flutter 3.x+ (`flutter doctor`)
- [x] Instalar Task (`go install github.com/go-task/task/v3/cmd/task@latest`)
- [x] Instalar Docker y Docker Compose
- [x] Instalar golangci-lint (`go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest`)

### 1.2 Flutter: crear proyecto real
- [x] Dentro de `mobile/`, ejecutar: `flutter create --org com.diruzorro --project-name diruzorro .`
- [x] Sustituir el `pubspec.yaml` generado con el que ya existe (o hacer merge)
- [x] Ejecutar `flutter pub get`
- [x] Verificar que compila: `flutter analyze`
- [x] Probar en emulador: `flutter run`

### 1.3 Backend: verificar
- [x] Ejecutar `task backend:run` — debe arrancar en puerto 8082
- [x] Probar health: `curl http://localhost:8080/health` → `{"status":"ok"}`
- [x] Probar auth: `curl -H "X-API-Key: dev-key-change-me" http://localhost:8080/api/v1/accounts` → `[]`

### 1.4 Docker
- [x] Copiar `deployments/.env.example` a `deployments/.env`
- [x] Rellenar `API_KEY` con un valor aleatorio
- [x] Ejecutar `task docker:up`
- [x] Verificar: `curl http://localhost:8080/health`
- [x] Parar: `task docker:down`

### 1.5 CI (opcional)
- [x] Crear `.github/workflows/ci.yaml` con jobs para:
  - `go test ./...`
  - `golangci-lint run`
  - `flutter test`
  - `flutter analyze`

---

## Fase 2: CRUD de Finanzas (Semana 3-4)

### 2.1 Backend: tests
- [x] Crear `backend/internal/repository/repository_test.go`
  - Test crear cuenta
  - Test crear categoría
  - Test crear transacción
  - Test filtrar transacciones por fecha
  - Test filtrar por categoría
- [x] Ejecutar `task backend:test` — todo verde

### 2.2 Flutter: pantalla de Cuentas
- [x] Implementar `AccountsView` completa:
  - Listar cuentas desde la API (usando Riverpod)
  - Mostrar nombre, tipo, saldo
  - Botón FAB para crear cuenta
  - Diálogo/pantalla de creación (nombre, tipo, moneda, saldo inicial)
  - Deslizar para eliminar
- [x] Probar con backend corriendo

### 2.3 Flutter: pantalla de Categorías
- [x] Crear `views/categories_view.dart`
- [x] Listar categorías con icono y color
- [x] Crear categoría (nombre, tipo, icono emoji, color)
- [x] Añadir acceso desde menú o settings

### 2.4 Flutter: pantalla de Transacciones
- [ ] Implementar `TransactionsView` completa:
  - Lista de transacciones ordenadas por fecha
  - Mostrar: importe, categoría (icono+color), descripción, fecha
  - Color verde para ingresos, rojo para gastos
  - FAB para crear transacción
- [ ] Pantalla de creación de transacción:
  - Selector de cuenta
  - Selector de categoría
  - Importe (teclado numérico)
  - Tipo (gasto/ingreso/transferencia)
  - Fecha (date picker)
  - Descripción
- [ ] Filtros: por fecha (rango), por categoría, por cuenta

### 2.5 Flutter: Home (resumen)
- [ ] Implementar `HomeView`:
  - Saldo total (suma de todas las cuentas)
  - Gastos del mes actual
  - Ingresos del mes actual
  - Últimas 5 transacciones
  - Tarjetas resumen de cada cuenta

---

## Fase 3: Presupuestos y Ahorro (Semana 5)

### 3.1 Backend: actualizar spent_amount
- [ ] Cuando se crea una transacción de tipo "expense":
  - Buscar presupuesto del mes/año para esa categoría
  - Si existe, incrementar `spent_amount`
- [ ] Cuando se elimina una transacción:
  - Decrementar `spent_amount` del presupuesto correspondiente
- [ ] Tests para esta lógica

### 3.2 Flutter: pantalla de Presupuestos
- [ ] Implementar `BudgetsView`:
  - Selector de mes/año
  - Lista de presupuestos con barra de progreso
  - Color verde si <80%, amarillo 80-100%, rojo si >100%
  - Crear nuevo presupuesto (categoría + límite)
- [ ] Notificación visual cuando un presupuesto supera el 80%

### 3.3 Flutter: pantalla de Objetivos de Ahorro
- [ ] Crear `views/savings_view.dart`
- [ ] Listar objetivos con:
  - Nombre, progreso (barra), importe actual / meta
  - Fecha objetivo (si existe)
- [ ] Crear objetivo: nombre, cantidad meta, fecha (opcional)
- [ ] Actualizar progreso manualmente (añadir cantidad)

---

## Fase 4: Informes y Gráficos (Semana 6)

### 4.1 Flutter: gastos por categoría
- [ ] En `ReportsView`, añadir pestaña "Por categoría"
- [ ] Gráfico circular (PieChart de fl_chart)
- [ ] Selector de rango de fechas
- [ ] Leyenda con categoría, color y total

### 4.2 Flutter: balance mensual
- [ ] Pestaña "Balance mensual"
- [ ] Gráfico de barras: ingresos (verde) vs gastos (rojo) por mes
- [ ] Selector de año
- [ ] Línea de balance (ingresos - gastos)

### 4.3 Flutter: tendencias
- [ ] Pestaña "Tendencias"
- [ ] Gráfico de líneas: evolución del gasto total por mes
- [ ] Selector de período (3, 6, 12 meses)
- [ ] Media móvil (opcional)

---

## Fase 5: Integración Bancaria PSD2 (Semana 7-8)

### 5.1 Registro en GoCardless
- [ ] Crear cuenta en https://bankaccountdata.gocardless.com/
- [ ] Obtener `secret_id` y `secret_key`
- [ ] Configurar en `deployments/.env`
- [ ] Probar obtener token de acceso (POST /token/new/)
- [ ] Probar listar instituciones españolas (GET /institutions/?country=es)

### 5.2 Backend: implementar cliente GoCardless
- [ ] Crear `backend/internal/banking/client.go`:
  - `GetToken()` — obtener/refrescar JWT
  - `ListInstitutions(country)` — listar bancos
  - `CreateRequisition(institutionID, redirectURL)` — iniciar flujo
  - `GetRequisition(id)` — consultar estado
  - `ListAccounts(requisitionID)` — obtener cuentas vinculadas
  - `GetTransactions(accountID)` — obtener transacciones
  - `GetBalances(accountID)` — obtener saldos

### 5.3 Backend: implementar handlers de banca
- [ ] `GET /banking/institutions` — devolver lista de bancos (cacheada)
- [ ] `POST /banking/connect` — crear requisición + devolver URL de autorización
- [ ] `GET /banking/callback` — recibir callback, actualizar estado de la conexión
- [ ] `POST /banking/sync` — importar transacciones nuevas
  - Evitar duplicados (por bank_transaction_id)
  - Crear transacciones en la tabla
  - Actualizar saldo de la cuenta

### 5.4 Flutter: flujo de conexión bancaria
- [ ] Crear `views/banking_view.dart`
- [ ] Pantalla: "Conectar banco"
  - Listar bancos disponibles con logo
  - Al seleccionar, abrir WebView/navegador para autorizar
  - Manejar callback (deep link o polling)
- [ ] Pantalla: "Cuentas bancarias"
  - Mostrar cuentas vinculadas
  - Botón "Sincronizar"
  - Mostrar última sincronización
  - Botón eliminar conexión

### 5.5 Testing
- [ ] Tests con mock de API GoCardless
- [ ] Probar flujo completo con sandbox de GoCardless
- [ ] Verificar que las transacciones importadas aparecen correctamente

---

## Fase 6: Pulido y Despliegue (Semana 9)

### 6.1 UX
- [ ] Loading states en todas las listas (shimmer o circular indicator)
- [ ] Pull-to-refresh en listas principales
- [ ] Empty states (ilustración + texto cuando no hay datos)
- [ ] Mensajes de error amigables (SnackBar)
- [ ] Confirmación antes de eliminar (diálogo)
- [ ] Tema oscuro verificado

### 6.2 Backend: robustez
- [ ] Rate limiting en endpoints sensibles
- [ ] Validación completa de inputs (importes positivos, fechas válidas, etc.)
- [ ] Logging de errores con contexto suficiente
- [ ] Endpoint de backup: `GET /api/v1/backup` → descargar DB completa

### 6.3 Despliegue producción
- [ ] Contratar VPS o usar servicio cloud (Hetzner, DigitalOcean, etc.)
- [ ] Configurar DNS (opcional: subdominio tipo api.tudominio.com)
- [ ] Instalar Caddy como reverse proxy con HTTPS automático
- [ ] Configurar docker-compose para producción
- [ ] Configurar backups automáticos de la DB (cron + rclone a cloud)
- [ ] Probar que la app Flutter conecta al servidor remoto

### 6.4 App: build de release
- [ ] Configurar URL del servidor en la app (configurable o hardcoded)
- [ ] `flutter build apk --release` — generar APK
- [ ] Instalar en tu teléfono y probar
- [ ] (Opcional) Subir a Google Play Store

---

## Extras (cuando quieras)

- [ ] Transacciones recurrentes (suscripciones, nómina, alquiler)
- [ ] Exportar datos a CSV
- [ ] Widget de resumen para la pantalla de inicio del móvil
- [ ] Categorización automática con reglas (si concepto contiene "Mercadona" → Alimentación)
- [ ] Multi-moneda con conversión
- [ ] Notificaciones push cuando se supera un presupuesto

---

## Notas

- El backend ya está implementado con todos los endpoints CRUD y reporting
- Los handlers de banca (PSD2) son placeholders — implementarlos en Fase 5
- La app Flutter tiene la estructura y navegación lista — implementar las vistas reales en Fases 2-4
- La especificación completa de la API está en `api/openapi.yaml`
