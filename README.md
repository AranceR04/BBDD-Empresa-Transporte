# BBDD-Empresa-Transporte
Arquitectura robusta para la base de datos de una empresa logística, distribución y transporte internacional. Está optimizada para manejar millones de registros mediante indexación estratégica, control estricto de tipos (ENUM), integridad referencial y modularidad operacional


1. Entidades Maestras (Infraestructura y Recursos)
• almacenes: Registra los Hubs de distribución, su ubicación global y capacidad en metros cúbicos (m³).
• clientes: Gestión centralizada de cuentas corporativas (B2B) y particulares (B2C).
• empleados: Control de nómina operativa diferenciando roles, asignación de sedes y licencias de conducir para operarios en ruta.
• vehiculos: Seguimiento de la flota (Tráileres, Camiones, Furgones), control de kilometraje, estado en tiempo real y cargas máximas toleradas.

2. Operaciones en Ruta y Consolidación de Carga
• envios: Gestión del paquete individual (origen/destino, cubicaje, peso, valor declarado para seguros y costes). Emplea códigos tracking con identificadores únicos universales (UUID).
• rutas: Asignación y planificación de trayectos intermodales uniendo Hubs de origen y destino, vinculando de manera estricta un chofer y un vehículo disponible.
• ruta_envios: Tabla intermedia de alta eficiencia para la consolidación de carga (muchos envíos en una sola ruta de transporte).

4. Auditoría, Mantenimiento y Trazabilidad
• historial_envios: La tabla encargada de alimentar los sistemas de Tracking. Guarda cada cambio de estado, hora exacta y la localización del paquete.
• mantenimientos: Control preventivo y correctivo de la flota para calcular costes de talleres mecánicos y amortización de activos.

6. Capa de Rendimiento y Negocio
• Indices Estratégicos (INDEX): Indexación en estados de envíos, IDs de clientes e históricos para agilizar las consultas web de cara al usuario final.
• Vista Analítica (vista_resumen_rutas): Una vista de negocio que calcula en tiempo real cuántos paquetes lleva un camión, el peso total consolidado y el porcentaje de optimización de la carga antes de salir del almacén.
