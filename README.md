# 📦 Evaluación Módulo 5 – Sistema de Gestión de Inventario

## 📌 Descripción
Proyecto académico que implementa un sistema de gestión de inventario en **MySQL**, con manejo de **productos, proveedores y transacciones** (compras/ventas).  
Incluye modelo conceptual, modelo relacional y script SQL con creación de tablas, restricciones, datos de prueba y consultas.

---

## 🗂️ Archivos
- `Conceptual.drawio` → Diagrama conceptual (ERD).  
- `Relacional.erd` → Modelo relacional.  
- `inventario_db.sql` → Script SQL con estructura, datos y consultas.  
- `Informe_EModulo.pdf` → Informe explicativo del proyecto.  

---

## 🚀 Ejecución
1. Abrir MySQL Workbench o cliente SQL.  
2. Crear la base de datos ejecutando:
   ```sql
   SOURCE inventario_db.sql;
Verificar tablas y datos:

```sql
Copiar código
SHOW TABLES;
SELECT * FROM productos;
SELECT * FROM transacciones;
```
✅ Notas
Requiere MySQL 8.0+.
Se utilizaron restricciones de integridad (CHECK, UNIQUE, FK) y transacciones atómicas para garantizar consistencia de datos.
El modelo está normalizado hasta 3FN.
