# Prototipo — Residencial Los Robles

Prototipo mínimo de 3 historias de usuario del sprint actual:

- **HU-05 · Base de datos y entorno** — la base SQLite se genera a partir de [`schema_los_robles.sql`](schema_los_robles.sql) y se sirve mediante Prisma + Express.
- **HU-01 · Registro de residente** — formulario que crea un usuario con rol `residente` ligado a una vivienda del padrón.
- **HU-02 · Login seguro** — autenticación con verificación de contraseña con bcrypt.

## Stack

- **Backend:** Node.js + Express + Prisma + SQLite (`server/`)
- **Frontend:** React + Vite + react-router (`client/`)
- **CSS:** mínimo, un solo archivo (`client/src/index.css`), sin framework

## Estructura

```
schema_los_robles.sql     ← script SQL original (fuente de verdad del esquema)
server/
  prisma/schema.prisma    ← modelos generados por introspección del .sql
  prisma/dev.db           ← base SQLite (se genera, no se versiona)
  index.js                ← API Express (3 endpoints)
client/
  src/App.jsx             ← Login, Register, Dashboard
```

## Requisitos

- Node.js **22+** (usa el módulo nativo `node:sqlite`, todavía experimental — verás un warning al arrancar el servidor, es normal e inofensivo).

## Puesta en marcha (dos terminales)

### 1. Generar la base de datos (solo la primera vez, o si borras `server/prisma/dev.db`)

```bash
cd server
node -e "
const { DatabaseSync } = require('node:sqlite');
const fs = require('fs');
const sql = fs.readFileSync('../schema_los_robles.sql', 'utf8');
const db = new DatabaseSync('./prisma/dev.db');
db.exec(sql);
console.log('DB creada');
db.close();
"
npx prisma generate
```

### 2. Levantar la API (puerto 4000)

```bash
cd server
npm install   # solo la primera vez
node index.js
```

Debe imprimir: `API escuchando en http://localhost:4000`

### 3. Levantar el frontend (puerto 5173), en otra terminal

```bash
cd client
npm install   # solo la primera vez
npm run dev
```

Abre `http://localhost:5173`.

## Flujo para probar

1. Entra a **Registrarse**, elige una vivienda del padrón (vienen precargadas del `.sql`), llena el formulario y envía.
2. Te redirige a **Iniciar sesión**; entra con el correo/contraseña que acabas de registrar.
3. Verás el **Dashboard** con tu nombre, correo, rol y vivienda — confirma que la API y la base de datos están conectadas end-to-end.

## Limitaciones conocidas (es un prototipo, no producción)

- **Los usuarios semilla del `.sql` no pueden iniciar sesión.** Sus `password_hash` son cadenas simuladas (`$2b$12$simulado_hash_...`), no hashes bcrypt reales — es intencional en el script original. Solo funcionan los usuarios creados desde el formulario de registro.
- No hay JWT ni tokens reales: la "sesión" vive únicamente en el estado de React (`useState`) y se pierde al recargar la página.
- No hay rutas protegidas: cualquiera puede navegar a `/dashboard` (mostrará "No has iniciado sesión" si no hay usuario en memoria).
- Sin validaciones de formato de correo/teléfono más allá de las básicas del navegador.
- CSS deliberadamente mínimo, sin diseño responsivo cuidado.

## Solución de problemas

- **La página no carga nada / errores de red al registrar o iniciar sesión:** confirma que la API (`node index.js` en `server/`) sigue corriendo — el frontend depende de `http://localhost:4000`. Prueba: `curl http://localhost:4000/api/viviendas`.
- **`EADDRINUSE` al iniciar `node index.js` o `npm run dev`:** ya hay un proceso usando ese puerto (4000 o 5173). Busca y detén el proceso anterior antes de volver a levantar.
- **Falta `server/prisma/dev.db` o da error de tabla no existe:** repite el paso 1 (regenerar la base) y vuelve a correr `npx prisma generate`.
- **Cambiaste `schema_los_robles.sql`:** borra `server/prisma/dev.db`, repite el paso 1, y vuelve a correr `npx prisma db pull && npx prisma generate` para refrescar los modelos.
