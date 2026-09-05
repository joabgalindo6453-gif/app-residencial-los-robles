-- ============================================================================
-- Sistema Web de Gestión Comunitaria — Residencial Los Robles
-- Script de base de datos (SQLite)
-- Equipo 3 | Proyecto 2 | Asesor: Héctor Humberto Valenzuela Rodríguez
-- Trazabilidad EDT: 1.5.1 (Diseño de base de datos) / HU-05 (Base de datos y entorno)
--
-- Módulos cubiertos (alcance del Acta Constitutiva v1.1):
--   - Usuarios, roles y viviendas (padrón)
--   - Cuotas de mantenimiento y pagos (simulados, sin pasarela real)
--   - Avisos y notificaciones
--   - Reportes / tickets de fallas y quejas
--   - Votaciones digitales
--   - Directorio institucional
--   - Sesiones (soporte para autenticación JWT del lado del cliente)
--
-- Nota académica: los datos incluidos al final del script son SIMULADOS,
-- conforme al criterio de aceptación del proyecto ("el sistema debe utilizar
-- datos simulados y consistentes"). No representan personas ni pagos reales.
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- 1. ROLES
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS roles;
CREATE TABLE roles (
    id_rol      INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre      TEXT NOT NULL UNIQUE CHECK (nombre IN ('administrador','mesa_directiva','residente','vigilancia')),
    descripcion TEXT
);

-- ----------------------------------------------------------------------------
-- 2. VIVIENDAS (padrón autorizado por la Mesa Directiva)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS viviendas;
CREATE TABLE viviendas (
    id_vivienda       INTEGER PRIMARY KEY AUTOINCREMENT,
    numero_vivienda   TEXT NOT NULL UNIQUE,      -- ej. 'MZ-12-LT-05'
    calle             TEXT,
    manzana           TEXT,
    lote              TEXT,
    propietario_nombre TEXT NOT NULL,
    estado            TEXT NOT NULL DEFAULT 'activa' CHECK (estado IN ('activa','inactiva')),
    fecha_alta        TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_viviendas_numero ON viviendas(numero_vivienda);

-- ----------------------------------------------------------------------------
-- 3. USUARIOS
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS usuarios;
CREATE TABLE usuarios (
    id_usuario      INTEGER PRIMARY KEY AUTOINCREMENT,
    id_vivienda     INTEGER,                     -- NULL para roles administrativos sin vivienda asociada
    id_rol          INTEGER NOT NULL,
    nombre_completo TEXT NOT NULL,
    correo          TEXT NOT NULL UNIQUE,
    password_hash   TEXT NOT NULL,                -- nunca texto plano (criterio de aceptación HU-01)
    telefono        TEXT,
    activo          INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0,1)),
    fecha_registro  TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (id_vivienda) REFERENCES viviendas(id_vivienda) ON DELETE SET NULL,
    FOREIGN KEY (id_rol) REFERENCES roles(id_rol) ON DELETE RESTRICT
);
CREATE INDEX idx_usuarios_correo   ON usuarios(correo);
CREATE INDEX idx_usuarios_vivienda ON usuarios(id_vivienda);

-- ----------------------------------------------------------------------------
-- 4. SESIONES (soporte de tokens JWT / recuperación de contraseña — HU-02)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS sesiones;
CREATE TABLE sesiones (
    id_sesion       INTEGER PRIMARY KEY AUTOINCREMENT,
    id_usuario      INTEGER NOT NULL,
    token_hash      TEXT NOT NULL,
    tipo            TEXT NOT NULL DEFAULT 'acceso' CHECK (tipo IN ('acceso','recuperacion_password')),
    fecha_creacion  TEXT NOT NULL DEFAULT (datetime('now')),
    fecha_expiracion TEXT NOT NULL,
    revocado        INTEGER NOT NULL DEFAULT 0 CHECK (revocado IN (0,1)),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
);
CREATE INDEX idx_sesiones_usuario ON sesiones(id_usuario);

-- ----------------------------------------------------------------------------
-- 5. CUOTAS (cargos generados por periodo) y PAGOS
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS cuotas;
CREATE TABLE cuotas (
    id_cuota        INTEGER PRIMARY KEY AUTOINCREMENT,
    id_vivienda     INTEGER NOT NULL,
    periodo         TEXT NOT NULL,                -- formato 'YYYY-MM'
    monto           REAL NOT NULL CHECK (monto >= 0),
    fecha_vencimiento TEXT NOT NULL,
    estado          TEXT NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente','pagada','vencida')),
    FOREIGN KEY (id_vivienda) REFERENCES viviendas(id_vivienda) ON DELETE CASCADE,
    UNIQUE (id_vivienda, periodo)
);
CREATE INDEX idx_cuotas_vivienda ON cuotas(id_vivienda);
CREATE INDEX idx_cuotas_estado   ON cuotas(estado);

DROP TABLE IF EXISTS pagos;
CREATE TABLE pagos (
    id_pago         INTEGER PRIMARY KEY AUTOINCREMENT,
    id_cuota        INTEGER NOT NULL,
    id_usuario      INTEGER,                      -- quién registró/realizó el pago
    monto_pagado    REAL NOT NULL CHECK (monto_pagado >= 0),
    metodo_pago     TEXT NOT NULL DEFAULT 'simulado' CHECK (metodo_pago IN ('simulado','transferencia','efectivo','tarjeta')),
    referencia      TEXT,                         -- folio simulado, sin integración real a pasarela
    fecha_pago      TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (id_cuota) REFERENCES cuotas(id_cuota) ON DELETE CASCADE,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE SET NULL
);
CREATE INDEX idx_pagos_cuota ON pagos(id_cuota);

-- ----------------------------------------------------------------------------
-- 6. AVISOS Y NOTIFICACIONES
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS avisos;
CREATE TABLE avisos (
    id_aviso        INTEGER PRIMARY KEY AUTOINCREMENT,
    id_autor        INTEGER NOT NULL,
    titulo          TEXT NOT NULL,
    contenido       TEXT NOT NULL,
    categoria       TEXT NOT NULL DEFAULT 'general' CHECK (categoria IN ('general','emergencia','financiero','evento')),
    prioridad       TEXT NOT NULL DEFAULT 'normal' CHECK (prioridad IN ('baja','normal','alta','urgente')),
    fecha_publicacion TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (id_autor) REFERENCES usuarios(id_usuario) ON DELETE RESTRICT
);
CREATE INDEX idx_avisos_fecha ON avisos(fecha_publicacion);

DROP TABLE IF EXISTS avisos_lecturas;
CREATE TABLE avisos_lecturas (
    id_aviso        INTEGER NOT NULL,
    id_usuario      INTEGER NOT NULL,
    fecha_lectura   TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (id_aviso, id_usuario),
    FOREIGN KEY (id_aviso) REFERENCES avisos(id_aviso) ON DELETE CASCADE,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- 7. REPORTES (tickets de fallas, quejas y emergencias) con seguimiento
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS reportes;
CREATE TABLE reportes (
    id_reporte      INTEGER PRIMARY KEY AUTOINCREMENT,
    id_usuario      INTEGER NOT NULL,
    id_vivienda     INTEGER,
    titulo          TEXT NOT NULL,
    descripcion     TEXT NOT NULL,
    categoria       TEXT NOT NULL DEFAULT 'falla' CHECK (categoria IN ('falla','queja','emergencia','sugerencia')),
    prioridad       TEXT NOT NULL DEFAULT 'normal' CHECK (prioridad IN ('baja','normal','alta','critica')),
    estado          TEXT NOT NULL DEFAULT 'abierto' CHECK (estado IN ('abierto','en_proceso','resuelto','cerrado')),
    fecha_creacion  TEXT NOT NULL DEFAULT (datetime('now')),
    fecha_actualizacion TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE RESTRICT,
    FOREIGN KEY (id_vivienda) REFERENCES viviendas(id_vivienda) ON DELETE SET NULL
);
CREATE INDEX idx_reportes_estado ON reportes(estado);

DROP TABLE IF EXISTS reportes_seguimiento;
CREATE TABLE reportes_seguimiento (
    id_seguimiento  INTEGER PRIMARY KEY AUTOINCREMENT,
    id_reporte      INTEGER NOT NULL,
    id_usuario      INTEGER NOT NULL,             -- quién comenta (residente o administrador)
    comentario      TEXT NOT NULL,
    fecha           TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (id_reporte) REFERENCES reportes(id_reporte) ON DELETE CASCADE,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE RESTRICT
);
CREATE INDEX idx_seguimiento_reporte ON reportes_seguimiento(id_reporte);

-- ----------------------------------------------------------------------------
-- 8. VOTACIONES DIGITALES
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS votaciones;
CREATE TABLE votaciones (
    id_votacion     INTEGER PRIMARY KEY AUTOINCREMENT,
    id_creador      INTEGER NOT NULL,
    titulo          TEXT NOT NULL,
    descripcion     TEXT,
    fecha_inicio    TEXT NOT NULL,
    fecha_fin       TEXT NOT NULL,
    estado          TEXT NOT NULL DEFAULT 'activa' CHECK (estado IN ('activa','cerrada','cancelada')),
    FOREIGN KEY (id_creador) REFERENCES usuarios(id_usuario) ON DELETE RESTRICT
);

DROP TABLE IF EXISTS opciones_votacion;
CREATE TABLE opciones_votacion (
    id_opcion       INTEGER PRIMARY KEY AUTOINCREMENT,
    id_votacion     INTEGER NOT NULL,
    texto_opcion    TEXT NOT NULL,
    FOREIGN KEY (id_votacion) REFERENCES votaciones(id_votacion) ON DELETE CASCADE
);

DROP TABLE IF EXISTS votos;
CREATE TABLE votos (
    id_voto         INTEGER PRIMARY KEY AUTOINCREMENT,
    id_votacion     INTEGER NOT NULL,
    id_opcion       INTEGER NOT NULL,
    id_usuario      INTEGER NOT NULL,
    fecha_voto      TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (id_votacion) REFERENCES votaciones(id_votacion) ON DELETE CASCADE,
    FOREIGN KEY (id_opcion) REFERENCES opciones_votacion(id_opcion) ON DELETE CASCADE,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    UNIQUE (id_votacion, id_usuario)               -- un residente = un voto por votación
);

-- ----------------------------------------------------------------------------
-- 9. DIRECTORIO INSTITUCIONAL
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS directorio;
CREATE TABLE directorio (
    id_directorio   INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre          TEXT NOT NULL,
    categoria       TEXT NOT NULL CHECK (categoria IN ('emergencia','administracion','proveedor','vigilancia')),
    telefono        TEXT,
    correo          TEXT,
    descripcion     TEXT
);

-- ============================================================================
-- DATOS SIMULADOS (para pruebas de los módulos — criterio de aceptación HU-05)
-- ============================================================================

INSERT INTO roles (nombre, descripcion) VALUES
    ('administrador',  'Administrador técnico del sistema'),
    ('mesa_directiva', 'Presidente, tesorera o secretario de la colonia'),
    ('residente',      'Propietario o habitante de una vivienda registrada'),
    ('vigilancia',     'Personal del comité de vigilancia');

INSERT INTO viviendas (numero_vivienda, calle, manzana, lote, propietario_nombre, estado) VALUES
    ('MZ-01-LT-01', 'Av. Robles Norte', '01', '01', 'Pedro Ramírez Solís',   'activa'),
    ('MZ-01-LT-02', 'Av. Robles Norte', '01', '02', 'Laura Fonseca Ibarra', 'activa'),
    ('MZ-02-LT-05', 'Calle Encinos',    '02', '05', 'Jaime Osorio Castillo','activa'),
    ('MZ-02-LT-06', 'Calle Encinos',    '02', '06', 'María Elena Padilla',  'activa'),
    ('MZ-03-LT-10', 'Calle Fresnos',    '03', '10', 'Ricardo Núñez Alba',   'activa'),
    ('MZ-03-LT-11', 'Calle Fresnos',    '03', '11', 'Sofía Camarena Ruiz',  'inactiva');

-- password_hash simulado (en producción real irían hashes bcrypt/argon2, no texto plano)
INSERT INTO usuarios (id_vivienda, id_rol, nombre_completo, correo, password_hash, telefono) VALUES
    (NULL, 1, 'Admin del Sistema',        'admin@losrobles.mx',    '$2b$12$simulado_hash_admin',    '3312340000'),
    (1,    2, 'Pedro Ramírez Solís',      'pedro.presidente@losrobles.mx',  '$2b$12$simulado_hash_pedro', '3312340001'),
    (2,    2, 'Laura Fonseca Ibarra',     'laura.tesorera@losrobles.mx',    '$2b$12$simulado_hash_laura', '3312340002'),
    (3,    2, 'Jaime Osorio Castillo',    'jaime.secretario@losrobles.mx',  '$2b$12$simulado_hash_jaime', '3312340003'),
    (4,    3, 'María Elena Padilla',      'maria.padilla@correo.mx',        '$2b$12$simulado_hash_maria', '3312340004'),
    (5,    3, 'Ricardo Núñez Alba',       'ricardo.nunez@correo.mx',        '$2b$12$simulado_hash_ricardo','3312340005'),
    (NULL, 4, 'Comité de Vigilancia Turno 1', 'vigilancia1@losrobles.mx',   '$2b$12$simulado_hash_vig1',   '3312340006');

INSERT INTO cuotas (id_vivienda, periodo, monto, fecha_vencimiento, estado) VALUES
    (1, '2026-07', 850.00, '2026-07-10', 'pagada'),
    (1, '2026-08', 850.00, '2026-08-10', 'pendiente'),
    (2, '2026-07', 850.00, '2026-07-10', 'pagada'),
    (2, '2026-08', 850.00, '2026-08-10', 'pagada'),
    (4, '2026-07', 850.00, '2026-07-10', 'vencida'),
    (5, '2026-08', 850.00, '2026-08-10', 'pendiente');

INSERT INTO pagos (id_cuota, id_usuario, monto_pagado, metodo_pago, referencia) VALUES
    (1, 2, 850.00, 'simulado', 'SIM-0001'),
    (3, 3, 850.00, 'transferencia', 'SIM-0002'),
    (4, 3, 850.00, 'transferencia', 'SIM-0003');

INSERT INTO avisos (id_autor, titulo, contenido, categoria, prioridad) VALUES
    (2, 'Corte de agua programado', 'El día 10 de septiembre habrá corte de agua de 9:00 a 14:00 hrs por mantenimiento de cisternas.', 'general', 'alta'),
    (3, 'Recordatorio de cuota de mantenimiento', 'Se recuerda a los residentes que la cuota de agosto vence el día 10.', 'financiero', 'normal'),
    (4, 'Asamblea general', 'Se convoca a asamblea general el 20 de septiembre a las 18:00 hrs en la caseta principal.', 'evento', 'normal');

INSERT INTO reportes (id_usuario, id_vivienda, titulo, descripcion, categoria, prioridad, estado) VALUES
    (5, 4, 'Luminaria fundida en la calle Encinos', 'La luminaria frente al lote 06 lleva una semana apagada.', 'falla', 'normal', 'abierto'),
    (6, 5, 'Fuga de agua en área común', 'Hay una fuga visible cerca del parque infantil.', 'emergencia', 'critica', 'en_proceso');

INSERT INTO reportes_seguimiento (id_reporte, id_usuario, comentario) VALUES
    (2, 1, 'Se notificó a mantenimiento, personal en sitio revisando la fuga.'),
    (2, 6, 'Vigilancia confirma que el área fue acordonada mientras se repara.');

INSERT INTO votaciones (id_creador, titulo, descripcion, fecha_inicio, fecha_fin, estado) VALUES
    (2, 'Instalación de cámaras adicionales', '¿Aprueba la instalación de 4 cámaras adicionales en accesos secundarios?', '2026-09-01', '2026-09-07', 'activa');

INSERT INTO opciones_votacion (id_votacion, texto_opcion) VALUES
    (1, 'A favor'),
    (1, 'En contra'),
    (1, 'Abstención');

INSERT INTO votos (id_votacion, id_opcion, id_usuario) VALUES
    (1, 1, 5),
    (1, 1, 6);

INSERT INTO directorio (nombre, categoria, telefono, correo, descripcion) VALUES
    ('Caseta de Vigilancia',        'vigilancia',     '3312340006', 'vigilancia1@losrobles.mx', 'Turno 1, 24 horas'),
    ('Administración Los Robles',  'administracion', '3312340000', 'admin@losrobles.mx',       'Oficina administrativa'),
    ('Plomería El Rápido',          'proveedor',      '3319998877', NULL,                       'Proveedor autorizado de plomería'),
    ('Bomberos (Municipal)',        'emergencia',     '911',        NULL,                       'Línea de emergencia municipal');

-- ============================================================================
-- Fin del script — integridad referencial habilitada con PRAGMA foreign_keys.
-- ============================================================================
