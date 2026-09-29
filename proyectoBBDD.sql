-- 1. EXTENSIONES Y ENUMS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE estado_empleado AS ENUM ('Activo', 'Licencia', 'Baja');
CREATE TYPE tipo_vehiculo AS ENUM ('Trailer', 'Camión Rígido', 'Furgón', 'Furgoneta', 'Pick-up');
CREATE TYPE estado_vehiculo AS ENUM ('Disponible', 'En Ruta', 'En Mantenimiento', 'Fuera de Servicio');
CREATE TYPE estado_envio AS ENUM ('Registrado', 'En Almacén', 'En Tránsito', 'En Reparto', 'Entregado', 'Incidencia');
CREATE TYPE tipo_mantenimiento AS ENUM ('Preventivo', 'Correctivo', 'Inspección');

-- 2. TABLAS INDEPENDIENTES / MAESTRAS

-- Almacenes / Centros de Distribución (Hubs)
CREATE TABLE almacenes (
    almacen_id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    codigo_hub VARCHAR(20) UNIQUE NOT NULL,
    direccion VARCHAR(200) NOT NULL,
    ciudad VARCHAR(100) NOT NULL,
    pais VARCHAR(100) NOT NULL,
    capacidad_m3 NUMERIC(12, 2) NOT NULL,
    telefono VARCHAR(20),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Clientes (B2B y B2C)
CREATE TABLE clientes (
    cliente_id SERIAL PRIMARY KEY,
    razon_social_nombre VARCHAR(150) NOT NULL,
    documento_identidad VARCHAR(50) UNIQUE NOT NULL, -- RUC, CIF, NIT, DNI
    tipo_cliente VARCHAR(20) CHECK (tipo_cliente IN ('Empresa', 'Particular')),
    correo VARCHAR(100),
    telefono VARCHAR(20),
    direccion_fiscal VARCHAR(200),
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Empleados (Conductores, Operadores, Administrativos)
CREATE TABLE empleados (
    empleado_id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    dni_pasaporte VARCHAR(50) UNIQUE NOT NULL,
    rol VARCHAR(50) NOT NULL, -- 'Conductor', 'Operario Almacén', 'Gestor Tráfico', etc.
    licencia_conducir VARCHAR(50), -- NULL si no es conductor
    telefono VARCHAR(20),
    fecha_contratacion DATE NOT NULL,
    estado estado_empleado DEFAULT 'Activo',
    almacen_asignado_id INT REFERENCES almacenes(almacen_id)
);

-- Flota de Vehículos
CREATE TABLE vehiculos (
    vehiculo_id SERIAL PRIMARY KEY,
    patente_matricula VARCHAR(20) UNIQUE NOT NULL,
    marca VARCHAR(50) NOT NULL,
    modelo VARCHAR(50) NOT NULL,
    tipo tipo_vehiculo NOT NULL,
    capacidad_carga_kg NUMERIC(10, 2) NOT NULL,
    volumen_max_m3 NUMERIC(8, 2) NOT NULL,
    kilometraje_actual INT DEFAULT 0,
    estado estado_vehiculo DEFAULT 'Disponible',
    fecha_adquisicion DATE
);

-- 3. TABLAS DE OPERACIONES (ENVÍOS Y RUTAS)

-- Envíos / Órdenes de Transporte
CREATE TABLE envios (
    envio_id SERIAL PRIMARY KEY,
    codigo_seguimiento UUID DEFAULT uuid_generate_v4() UNIQUE,
    cliente_id INT NOT NULL REFERENCES clientes(cliente_id),
    remitente_nombre VARCHAR(100) NOT NULL,
    remitente_direccion VARCHAR(200) NOT NULL,
    remitente_ciudad VARCHAR(100) NOT NULL,
    destinatario_nombre VARCHAR(100) NOT NULL,
    destinatario_direccion VARCHAR(200) NOT NULL,
    destinatario_ciudad VARCHAR(100) NOT NULL,
    peso_kg NUMERIC(10, 2) NOT NULL,
    volumen_m3 NUMERIC(8, 2) NOT NULL,
    valor_declarado NUMERIC(12, 2),
    costo_envio NUMERIC(12, 2) NOT NULL,
    estado_actual estado_envio DEFAULT 'Registrado',
    fecha_ingreso TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_entrega_estimada TIMESTAMP,
    fecha_entrega_real TIMESTAMP
);

-- Rutas / Viajes Principales
CREATE TABLE rutas (
    ruta_id SERIAL PRIMARY KEY,
    codigo_ruta VARCHAR(50) UNIQUE NOT NULL,
    almacen_origen_id INT NOT NULL REFERENCES almacenes(almacen_id),
    almacen_destino_id INT NOT NULL REFERENCES almacenes(almacen_id),
    vehiculo_id INT REFERENCES vehiculos(vehiculo_id),
    conductor_id INT REFERENCES empleados(empleado_id),
    fecha_salida_programada TIMESTAMP NOT NULL,
    fecha_llegada_programada TIMESTAMP NOT NULL,
    fecha_salida_real TIMESTAMP,
    fecha_llegada_real TIMESTAMP,
    kilometros_estimados NUMERIC(8, 2),
    estado_ruta VARCHAR(20) CHECK (estado_ruta IN ('Planificada', 'En Progreso', 'Completada', 'Cancelada')) DEFAULT 'Planificada'
);

-- Tabla Intermedia: Envíos asignados a una Ruta (Consolidación de Carga)
CREATE TABLE ruta_envios (
    ruta_id INT REFERENCES rutas(ruta_id) ON DELETE CASCADE,
    envio_id INT REFERENCES envios(envio_id) ON DELETE CASCADE,
    fecha_asignacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (ruta_id, envio_id)
);

-- 4. HISTORIAL, SEGUIMIENTO Y MANTENIMIENTO

-- Historial de Estados del Envío (Tracking)
CREATE TABLE historial_envios (
    historial_id SERIAL PRIMARY KEY,
    envio_id INT NOT NULL REFERENCES envios(envio_id) ON DELETE CASCADE,
    estado estado_envio NOT NULL,
    ubicacion_actual VARCHAR(150) NOT NULL, -- Puede ser una ciudad o el nombre de un almacén
    descripcion VARCHAR(250),
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Registro de Mantenimiento de Vehículos
CREATE TABLE mantenimientos (
    mantenimiento_id SERIAL PRIMARY KEY,
    vehiculo_id INT NOT NULL REFERENCES vehiculos(vehiculo_id) ON DELETE CASCADE,
    tipo tipo_mantenimiento NOT NULL,
    descripcion TEXT NOT NULL,
    costo NUMERIC(12, 2) NOT NULL,
    kilometraje_servicio INT NOT NULL,
    fecha_servicio DATE NOT NULL,
    taller_encargado VARCHAR(100)
);

-- 5. VISTAS RELEVANTES DE CONTROL

-- Vista de Ocupación actual de Rutas
CREATE OR REPLACE VIEW vista_resumen_rutas AS
SELECT 
    r.ruta_id,
    r.codigo_ruta,
    ao.nombre AS origen,
    ad.nombre AS destino,
    v.patente_matricula AS vehiculo,
    CONCAT(e.nombre, ' ', e.apellido) AS conductor,
    COUNT(re.envio_id) AS total_paquetes,
    COALESCE(SUM(en.peso_kg), 0) AS peso_total_cargado,
    v.capacidad_carga_kg AS capacidad_max_vehiculo,
    ROUND((COALESCE(SUM(en.peso_kg), 0) / v.capacidad_carga_kg) * 100, 2) AS porcentaje_uso_peso
FROM rutas r
JOIN almacenes ao ON r.almacen_origen_id = ao.almacen_id
JOIN almacenes ad ON r.almacen_destino_id = ad.almacen_id
LEFT JOIN vehiculos v ON r.vehiculo_id = v.vehiculo_id
LEFT JOIN empleados e ON r.conductor_id = e.empleado_id
LEFT JOIN ruta_envios re ON r.ruta_id = re.ruta_id
LEFT JOIN envios en ON re.envio_id = en.envio_id
GROUP BY r.ruta_id, r.codigo_ruta, ao.nombre, ad.nombre, v.patente_matricula, e.nombre, e.apellido, v.capacidad_carga_kg;

-- 6. INDEXACIÓN PARA RENDIMIENTO
CREATE INDEX idx_envios_estado ON envios(estado_actual);
CREATE INDEX idx_envios_cliente ON envios(cliente_id);
CREATE INDEX idx_rutas_fechas ON rutas(fecha_salida_programada);
CREATE INDEX idx_historial_envio ON historial_envios(envio_id);
