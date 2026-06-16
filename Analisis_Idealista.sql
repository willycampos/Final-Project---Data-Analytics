CREATE DATABASE idealista
GO
USE idealista
GO
-- Verifica si tienes habilitado 'Ad Hoc Distributed Queries'
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
GO
-- 1. Limpieza de Datos (Data Wrangling)
-- Creamos una vista con la data limpia
-- 1. Calculamos primero la mediana del año
-- Eliminamos la vista si ya existe para evitar errores de duplicado
IF OBJECT_ID('vw_houses_Madrid_Clean', 'V') IS NOT NULL 
    DROP VIEW vw_houses_Madrid_Clean;
GO
CREATE VIEW vw_houses_Madrid_Clean AS
SELECT 
    h.buy_price,
    
    -- 1. Corrección de Escala para Metros Cuadrados (640 -> 64.0)
    CASE 
        WHEN h.sq_mt_built > 100 AND h.n_rooms <= 4 THEN h.sq_mt_built / 10
        ELSE h.sq_mt_built 
    END AS sq_mt_built_corr,

    ISNULL(h.n_rooms, 1) AS n_rooms,

    -- 2. Corrección de Escala para Baños (15 -> 1.5)
    -- Si hay más de 10 baños y la casa no es una mansión gigante, dividimos por 10.
    CASE 
        WHEN h.n_bathrooms >= 10 THEN h.n_bathrooms / 10.0
        ELSE ISNULL(h.n_bathrooms, 1)
    END AS n_bathrooms_corr,
    
    -- C. Planta
    CASE 
        WHEN h.floor LIKE '%Sótano%' THEN -1
        WHEN h.floor LIKE '%Bajo%' THEN 0
        WHEN h.floor LIKE '%Entreplanta%' THEN 1
        WHEN h.floor IS NULL THEN 1
        ELSE TRY_CAST(h.floor AS FLOAT)
    END AS floor_numeric,

    -- D. Booleanos
    CASE WHEN h.has_lift IN ('True', '1') THEN 1 ELSE 0 END AS has_lift,
    CASE WHEN h.is_exterior IN ('True', '1') THEN 1 ELSE 0 END AS is_exterior,
    CASE WHEN h.has_parking IN ('True', '1') THEN 1 ELSE 0 END AS has_parking,
    CASE WHEN h.is_renewal_needed IN ('True', '1') THEN 1 ELSE 0 END AS is_renewal_needed,
    CASE WHEN h.has_terrace IN ('True', '1') THEN 1 ELSE 0 END AS has_terrace,
    CASE WHEN h.has_storage_room IN ('True', '1') THEN 1 ELSE 0 END AS has_storage_room,
    CASE WHEN h.is_new_development IN ('True', '1') THEN 1 ELSE 0 END AS is_new_development,

    -- E. IDs
    ISNULL(TRY_CAST(LEFT(SUBSTRING(h.neighborhood_id, PATINDEX('%[0-9]%', h.neighborhood_id), 50), 
             CHARINDEX(':', SUBSTRING(h.neighborhood_id, PATINDEX('%[0-9]%', h.neighborhood_id), 50) + ':') - 1) AS INT), 0) AS neighborhood_id_num,
    
    ISNULL(TRY_CAST(LEFT(SUBSTRING(h.house_type_id, PATINDEX('%[0-9]%', h.house_type_id), 50), 
             CHARINDEX(':', SUBSTRING(h.house_type_id, PATINDEX('%[0-9]%', h.house_type_id), 50) + ':') - 1) AS INT), 1) AS house_type_id_num,

    -- F. Año de construcción (con rescate de ceros extra)
    CASE 
        WHEN TRY_CAST(h.built_year AS INT) BETWEEN 1700 AND 2026 THEN TRY_CAST(h.built_year AS INT)
        WHEN TRY_CAST(h.built_year AS INT) BETWEEN 17000 AND 20260 THEN TRY_CAST(h.built_year AS INT) / 10
        ELSE 1970 
    END AS built_year_clean

FROM houses_Madrid h
WHERE h.buy_price IS NOT NULL 
  AND h.sq_mt_built IS NOT NULL;
GO
-- ======================================================
-- SCRIPT DE AUDITORÍA: VALIDACIÓN DE LIMPIEZA EN LA VISTA
-- ======================================================

-- 1. Conteo de valores NULOS en la vista
-- Si el resultado es 0 en todas las columnas, el Data Wrangling fue un éxito.
SELECT 
    SUM(CASE WHEN buy_price IS NULL THEN 1 ELSE 0 END) AS Nulos_Precio,
    SUM(CASE WHEN sq_mt_built_corr IS NULL THEN 1 ELSE 0 END) AS Nulos_Metros,
    SUM(CASE WHEN n_rooms IS NULL THEN 1 ELSE 0 END) AS Nulos_Habitaciones,
    SUM(CASE WHEN n_bathrooms_corr IS NULL THEN 1 ELSE 0 END) AS Nulos_Baños,
    SUM(CASE WHEN floor_numeric IS NULL THEN 1 ELSE 0 END) AS Nulos_Planta,
    SUM(CASE WHEN neighborhood_id_num IS NULL THEN 1 ELSE 0 END) AS Nulos_BarrioID,
    SUM(CASE WHEN house_type_id_num IS NULL THEN 1 ELSE 0 END) AS Nulos_TipoCasaID,
    SUM(CASE WHEN built_year_clean IS NULL THEN 1 ELSE 0 END) AS Nulos_Año,
    -- Validación de booleanos convertidos
    SUM(CASE WHEN has_lift IS NULL THEN 1 ELSE 0 END) AS Nulos_Ascensor,
    SUM(CASE WHEN is_renewal_needed IS NULL THEN 1 ELSE 0 END) AS Nulos_Reforma
FROM vw_houses_Madrid_Clean;

-- 2. Verificación de consistencia de datos (Strings que no se pudieron convertir)
-- Buscamos si el ID de barrio o tipo de casa se quedó en 0 por un error de casteo
SELECT 
    COUNT(*) AS Registros_Con_ID_Cero,
    (SELECT COUNT(*) FROM vw_houses_Madrid_Clean) AS Total_Registros,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM vw_houses_Madrid_Clean) AS DECIMAL(5,2)) AS Porcentaje_ID_No_Detectado
FROM vw_houses_Madrid_Clean
WHERE neighborhood_id_num = 0 OR house_type_id_num = 0;

-- 3. Análisis de rangos (Para detectar valores incoherentes tras la limpieza)
SELECT 
    MIN(floor_numeric) AS Planta_Minima, -- Debería ser -1 (Sótanos)
    MAX(floor_numeric) AS Planta_Maxima,
    MIN(built_year_clean) AS Año_Minimo,
    MAX(built_year_clean) AS Año_Maximo,
    AVG(n_rooms) AS Media_Habitaciones
FROM vw_houses_Madrid_Clean;
GO
-- vista de 10 registros
SELECT * FROM vw_houses_Madrid_Clean
GO
-- . Consulta de Correlación de Pearson (Precio vs. Todo)
SELECT 
    -- Correlación con Metros Cuadrados (Suele ser la más alta)
    (COUNT(*) * SUM(CAST(sq_mt_built_corr AS FLOAT) * CAST(buy_price AS FLOAT)) - SUM(CAST(sq_mt_built_corr AS FLOAT)) * SUM(CAST(buy_price AS FLOAT))) /
    (SQRT((COUNT(*) * SUM(SQUARE(CAST(sq_mt_built_corr AS FLOAT))) - SQUARE(SUM(CAST(sq_mt_built_corr AS FLOAT)))) * 
          (COUNT(*) * SUM(SQUARE(CAST(buy_price AS FLOAT))) - SQUARE(SUM(CAST(buy_price AS FLOAT)))))) AS Corr_Precio_Metros,

    -- Correlación con Habitaciones
    (COUNT(*) * SUM(CAST(n_rooms AS FLOAT) * CAST(buy_price AS FLOAT)) - SUM(CAST(n_rooms AS FLOAT)) * SUM(CAST(buy_price AS FLOAT))) /
    (SQRT((COUNT(*) * SUM(SQUARE(CAST(n_rooms AS FLOAT))) - SQUARE(SUM(CAST(n_rooms AS FLOAT)))) * 
          (COUNT(*) * SUM(SQUARE(CAST(buy_price AS FLOAT))) - SQUARE(SUM(CAST(buy_price AS FLOAT)))))) AS Corr_Precio_Habitaciones,

    -- Correlación con Ascensor (Impacto de comodidad)
    (COUNT(*) * SUM(CAST(has_lift AS FLOAT) * CAST(buy_price AS FLOAT)) - SUM(CAST(has_lift AS FLOAT)) * SUM(CAST(buy_price AS FLOAT))) /
    (SQRT((COUNT(*) * SUM(SQUARE(CAST(has_lift AS FLOAT))) - SQUARE(SUM(CAST(has_lift AS FLOAT)))) * 
          (COUNT(*) * SUM(SQUARE(CAST(buy_price AS FLOAT))) - SQUARE(SUM(CAST(buy_price AS FLOAT)))))) AS Corr_Precio_Ascensor
FROM vw_houses_Madrid_Clean;
GO
-- Insight de Negocio: Rentabilidad por Barrio
SELECT TOP 10
    neighborhood_id_num AS Barrio_ID,
    COUNT(*) AS Total_Viviendas,
    CAST(AVG(buy_price / sq_mt_built_corr) AS DECIMAL(10,2)) AS Precio_m2_Promedio,
    AVG(built_year_clean) AS Antiguedad_Promedio
FROM vw_houses_Madrid_Clean
GROUP BY neighborhood_id_num
HAVING COUNT(*) > 50 -- Filtramos para tener barrios con datos representativos
ORDER BY Precio_m2_Promedio DESC;
GO


