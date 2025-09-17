DROP DATABASE IF EXISTS inventario_db;
CREATE DATABASE inventario_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE inventario_db;

-- Asegurar check y comportamientos estrictos
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- Creaciónde Tablas

CREATE TABLE proveedores (
  proveedor_id   INT PRIMARY KEY AUTO_INCREMENT,
  nombre         VARCHAR(50) NOT NULL,
  direccion      VARCHAR(50) NOT NULL,
  telefono       VARCHAR(20) NOT NULL,
  email          VARCHAR(50) NOT NULL,
  UNIQUE (email)
);

CREATE TABLE productos (
  producto_id    INT PRIMARY KEY AUTO_INCREMENT,
  nombre         VARCHAR(50) NOT NULL,
  descripcion    TEXT,
  precio         DECIMAL (10,2) NOT NULL,
  cantidad       INT NOT NULL DEFAULT 0,
  fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_productos_nombre UNIQUE (nombre),
  CONSTRAINT ck_productos_precio CHECK (precio > 0),
  CONSTRAINT ck_productos_cantidad CHECK (cantidad >= 0)
);

CREATE TABLE transacciones (
  transaccion_id   BIGINT PRIMARY KEY AUTO_INCREMENT,
  tipo             ENUM('compra','venta') NOT NULL,
  fecha            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  cantidad         INT NOT NULL,
  precio_unitario  DECIMAL (10,2) NOT NULL,
  producto_id      INT NOT NULL,
  proveedor_id     INT NOT NULL,
  CONSTRAINT ck_transacciones_cantidad CHECK (cantidad > 0),
  CONSTRAINT ck_transacciones_precio CHECK (precio_unitario > 0),
  CONSTRAINT fk_transacciones_producto  FOREIGN KEY (producto_id)  REFERENCES productos(producto_id)  ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_transacciones_proveedor FOREIGN KEY (proveedor_id) REFERENCES proveedores(proveedor_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Índices de apoyo a consultas frecuentes
CREATE INDEX idx_transacciones_producto ON transacciones(producto_id);
CREATE INDEX idx_transacciones_proveedor ON transacciones(proveedor_id);
CREATE INDEX idx_transacciones_fecha ON transacciones(fecha);
CREATE INDEX idx_transacciones_tipo  ON transacciones(tipo);

-- Datos de prueba
INSERT INTO proveedores (nombre, direccion, telefono, email) VALUES
('TecnoWorld', 'Av. Central 123', '22223333', 'contacto@tecnoworld.cl'),
('Global Parts', 'Calle Norte 456', '24445555', 'ventas@globalparts.com'),
('ElectroChile', 'Pasaje Sur 789', '26667777', 'hola@electrochile.cl');

INSERT INTO productos (nombre, descripcion, precio, cantidad) VALUES
('Mouse Óptico', 'Mouse USB 1600dpi', 8.990, 100),
('Teclado Mecánico', 'Switch rojo, RGB', 49.990, 50),
('Monitor 24"', 'IPS 75Hz FullHD', 129.990, 20);

-- Compras iniciales (transacción para aumentar inventario)
START TRANSACTION;
  INSERT INTO transacciones (tipo, cantidad, precio_unitario, producto_id, proveedor_id)
  VALUES 
  ('compra', 30, 7.990, 1, 1),
  ('compra', 10, 119.990, 3, 2),
  ('compra', 20, 45.990, 2, 3);

  -- Actualizar inventario y precio de lista a último precio_unitario
  UPDATE productos SET cantidad = cantidad + 30,  precio = 7.990  WHERE producto_id = 1;
  UPDATE productos SET cantidad = cantidad + 10,  precio = 119.990 WHERE producto_id = 3;
  UPDATE productos SET cantidad = cantidad + 20,  precio = 45.990  WHERE producto_id = 2;
COMMIT;

-- Consultas Básicas
--- 1) Todos los productos
SELECT producto_id, nombre, descripcion, precio, cantidad FROM productos ORDER BY nombre;

--- 2) Proveedores que suministran un producto especifico por nombre
SELECT DISTINCT p.proveedor_id, p.nombre, p.email
FROM proveedores p
JOIN transacciones t ON p.proveedor_id = t.proveedor_id
JOIN productos pr ON pr.producto_id = t.producto_id
WHERE t.tipo = 'compra' AND pr.nombre = 'Mouse Óptico';

--- 3) Transacciones en una fecha específica 
SELECT *
FROM transacciones
WHERE fecha BETWEEN '2025-09-17 00:00:00' AND '2025-09-17 23:59:59'
ORDER BY fecha;

--- 4) Agregaciones: total unidades vendidas y valor total comprado
SELECT
  SUM(CASE WHEN tipo = 'venta' THEN cantidad ELSE 0 END) AS total_unidades_vendidas,
  SUM(CASE WHEN tipo = 'compra' THEN cantidad * precio_unitario ELSE 0 END) AS total_valor_compras
FROM transacciones;

--- Manipulación (DML) con integridad referencial
--- 1) Insertar un nuevo producto / proveedor / transacción de compra
INSERT INTO productos (nombre, descripcion, precio, cantidad) 
VALUES ('Webcam HD', 'Webcam 1080p con mic', 19.990, 0);
 
INSERT INTO proveedores (nombre, direccion, telefono, email) 
VALUES ('Logitech', 'Av. Central 123', '22223333', 'contacto@logitech.cl');

-- Registrar compra y actualizar inventario en una transacción atómica
START TRANSACTION;
  INSERT INTO transacciones (tipo, cantidad, precio_unitario, producto_id, proveedor_id)
  VALUES ('compra', 15, 17.990, (SELECT producto_id FROM productos WHERE nombre='Webcam HD'), 
                              (SELECT proveedor_id FROM proveedores WHERE nombre='Logitech'));
  UPDATE productos SET cantidad = cantidad + 15, precio = 17.990
  WHERE nombre='Webcam HD';
  
COMMIT;

--- 2) Actualizar inventario tras una VENTA (control simple con opción segura, verificando stock)
START TRANSACTION;

INSERT INTO transacciones (tipo, cantidad, precio_unitario, producto_id, proveedor_id)
SELECT 'venta', 5, p.precio, p.producto_id, pr.proveedor_id
FROM productos p
JOIN proveedores pr ON pr.nombre = 'ElectroChile'
WHERE p.nombre = 'Teclado Mecánico'
  AND p.cantidad >= 5;   -- aquí validamos el stock

UPDATE productos
SET cantidad = cantidad - 5
WHERE nombre = 'Teclado Mecánico' AND cantidad >= 5;

COMMIT;

---Eliminar un producto (solo si no está referenciado por transacciones)
-- (Si está referenciado, ON DELETE RESTRICT impedirá borrarlo)
-- DELETE FROM productos WHERE producto_id = 999;

---  Total de ventas (unidades y monto) de un producto en el mes ANTERIOR
-- Ventana de fechas: primer día del mes anterior -> último día del mes anterior
SET @inicio_mes_ant = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 MONTH), '%Y-%m-01');
SET @fin_mes_ant    = LAST_DAY(DATE_SUB(CURDATE(), INTERVAL 1 MONTH));

SELECT pr.nombre AS producto,
       SUM(t.cantidad) AS unidades_vendidas,
       SUM(t.cantidad * t.precio_unitario) AS monto_total_vendido
FROM transacciones t
JOIN productos pr ON pr.producto_id = t.producto_id
WHERE t.tipo='venta'
  AND t.producto_id = (SELECT producto_id FROM productos WHERE nombre='Mouse Óptico')
  AND t.fecha BETWEEN @inicio_mes_ant AND @fin_mes_ant
GROUP BY pr.nombre;

-- JOINs para ver detalle completo
-- INNER JOIN: solo transacciones que tienen producto y proveedor válidos
SELECT t.transaccion_id, t.tipo, t.fecha, t.cantidad, t.precio_unitario,
       pr.nombre AS producto, pv.nombre AS proveedor
FROM transacciones t
JOIN productos pr  ON pr.producto_id = t.producto_id
JOIN proveedores pv ON pv.proveedor_id = t.proveedor_id
ORDER BY t.fecha DESC;

-- LEFT JOIN: todos los productos y, si existen, su última transacción
SELECT p.producto_id, p.nombre, p.cantidad,
       t2.tipo, t2.fecha, t2.cantidad AS cant_transaccion
FROM productos p
LEFT JOIN (
  SELECT t.*
  FROM transacciones t
  JOIN (
    SELECT producto_id, MAX(fecha) AS max_fecha
    FROM transacciones
    GROUP BY producto_id
  ) ult ON ult.producto_id = t.producto_id AND ult.max_fecha = t.fecha
) t2 ON t2.producto_id = p.producto_id
ORDER BY p.nombre;

-- Subconsulta: productos NO vendidos en un período dado
SET @inicio = '2025-08-01';
SET @fin    = '2025-08-31';
SELECT p.producto_id, p.nombre
FROM productos p
WHERE p.producto_id NOT IN (
  SELECT DISTINCT t.producto_id
  FROM transacciones t
  WHERE t.tipo = 'venta'
    AND t.fecha BETWEEN @inicio AND @fin
)
ORDER BY p.nombre;