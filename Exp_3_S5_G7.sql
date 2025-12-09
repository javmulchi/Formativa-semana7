-----------------------------------------------------------
-- SEMANA 7 - Actividad formativa
-- Asignatura: Consulta de datos
-- Integrantes: Andrea Rosero, Javiera Mulchi
-----------------------------------------------------------

/*=========================================================
  CASO 1: Bonificación trabajador
=========================================================*/

SELECT 
    t.numrut AS rut,
    t.nombre || ' ' || t.appaterno || ' ' || t.apmaterno AS nombre_completo,
    t.sueldo_base,

--Bonificacion por ticket
    CASE 
        WHEN tc.monto_ticket IS NULL THEN 0
        WHEN tc.monto_ticket <= 50000 THEN 0
        WHEN tc.monto_ticket > 50000 AND tc.monto_ticket <= 100000 THEN ROUND(tc.monto_ticket * 0.05)
        WHEN tc.monto_ticket > 100000 THEN ROUND(tc.monto_ticket * 0.07)
    END AS bonificacion_ticket,

--Simulación de sueldo + ticket
    CASE 
        WHEN tc.monto_ticket IS NULL THEN t.sueldo_base
        WHEN tc.monto_ticket <= 50000 THEN t.sueldo_base
        WHEN tc.monto_ticket > 50000 AND tc.monto_ticket <= 100000 THEN t.sueldo_base + ROUND(tc.monto_ticket * 0.05)
        WHEN tc.monto_ticket > 100000 THEN t.sueldo_base + ROUND(tc.monto_ticket * 0.07)
    END AS simulacion_ticket,

--Años antiguedad
    FLOOR(MONTHS_BETWEEN(SYSDATE, t.fecing) / 12) AS años_antiguedad,

    ba.porcentaje AS porcentaje_antiguedad,

--Bono antiguedad

    ROUND(t.sueldo_base * (1 + ba.porcentaje)) AS simulacion_antiguedad
FROM trabajador t
LEFT JOIN tickets_concierto tc 
       ON t.numrut = tc.numrut_t
JOIN bono_antiguedad ba 
       ON FLOOR(MONTHS_BETWEEN(SYSDATE, t.fecing) / 12)
          BETWEEN ba.limite_inferior AND ba.limite_superior
JOIN isapre i 
       ON t.cod_isapre = i.cod_isapre
WHERE 
    i.porc_descto_isapre > 4 
    AND FLOOR(MONTHS_BETWEEN(SYSDATE, t.fecnac) / 12) < 50
ORDER BY simulacion_ticket DESC, nombre_completo ASC;

--Bonificaciones trabajadores

INSERT INTO detalle_bonificaciones_trabajador (
    num,
    rut,
    nombre_trabajador,
    sueldo_base,
    num_ticket,
    direccion,
    sistema_salud,
    monto,
    bonif_x_ticket,
    simulacion_x_ticket,
    simulacion_antiguedad
)
SELECT 
    seq_det_bonif.NEXTVAL AS num,
    TO_CHAR(t.numrut) AS rut,
    t.nombre || ' ' || t.appaterno || ' ' || t.apmaterno AS nombre_trabajador,
    TO_CHAR(t.sueldo_base) AS sueldo_base,
    TO_CHAR(tc.nro_ticket) AS num_ticket,
    t.direccion,
    i.nombre_isapre AS sistema_salud,
    TO_CHAR(tc.monto_ticket) AS monto,

-- Bonificación por ticket 
    TO_CHAR(
        CASE 
            WHEN tc.monto_ticket IS NULL THEN 0
            WHEN tc.monto_ticket <= 50000 THEN 0
            WHEN tc.monto_ticket > 50000 AND tc.monto_ticket <= 100000 THEN ROUND(tc.monto_ticket * 0.05)
            WHEN tc.monto_ticket > 100000 THEN ROUND(tc.monto_ticket * 0.07)
        END
    ) AS bonif_x_ticket,

-- Simulación sueldo + bonificación  
    TO_CHAR(
        CASE 
            WHEN tc.monto_ticket IS NULL THEN t.sueldo_base
            WHEN tc.monto_ticket <= 50000 THEN t.sueldo_base
            WHEN tc.monto_ticket > 50000 AND tc.monto_ticket <= 100000 THEN t.sueldo_base + ROUND(tc.monto_ticket * 0.05)
            WHEN tc.monto_ticket > 100000 THEN t.sueldo_base + ROUND(tc.monto_ticket * 0.07)
        END
    ) AS simulacion_x_ticket,

--Simulación de sueldo 
    TO_CHAR(ROUND(t.sueldo_base * (1 + ba.porcentaje))) AS simulacion_antiguedad
FROM trabajador t
JOIN tickets_concierto tc         
       ON t.numrut = tc.numrut_t
JOIN bono_antiguedad ba 
       ON FLOOR(MONTHS_BETWEEN(SYSDATE, t.fecing) / 12)
          BETWEEN ba.limite_inferior AND ba.limite_superior
JOIN isapre i 
       ON t.cod_isapre = i.cod_isapre
WHERE 
    i.porc_descto_isapre > 4 
    AND FLOOR(MONTHS_BETWEEN(SYSDATE, t.fecnac) / 12) < 50;

COMMIT;

/*=========================================================
  CASO 2: Vistas tapa 1
=========================================================*/

CREATE OR REPLACE SYNONYM syn_trabajador   FOR trabajador;
CREATE OR REPLACE SYNONYM syn_bono_escolar FOR bono_escolar;

-- Vista de aumentos por estudios
CREATE OR REPLACE VIEW V_AUMENTOS_ESTUDIOS AS
SELECT 
    t.numrut AS rut,
    t.nombre || ' ' || t.appaterno || ' ' || t.apmaterno AS nombre_completo,
    be.descrip AS nivel,                    
    be.porc_bono AS porcentaje_bono_estudio,
    t.sueldo_base,
    
--Aumento por estudios
    ROUND(t.sueldo_base * be.porc_bono / 100) AS aumento_estudios,

    ROUND(t.sueldo_base + (t.sueldo_base * be.porc_bono / 100)) AS sueldo_con_aumento,

    (SELECT COUNT(*) 
       FROM asignacion_familiar af 
      WHERE af.numrut_t = t.numrut) AS cantidad_cargas
FROM syn_trabajador t
JOIN syn_bono_escolar be 
       ON t.id_escolaridad_t = be.id_escolar
JOIN tipo_trabajador tt
       ON t.id_categoria_t = tt.id_categoria
WHERE tt.desc_categoria = 'CAJERO'
  AND (SELECT COUNT(*) 
         FROM asignacion_familiar af 
        WHERE af.numrut_t = t.numrut) IN (1, 2)
ORDER BY be.porc_bono ASC, nombre_completo ASC;


/*=========================================================
  CASO 2: Vistas etapa 2- optimizacion de consulta
=========================================================*/

-- Índices para búsqueda por apellido materno
CREATE INDEX idx_trabajador_ap_materno 
    ON trabajador(apmaterno);

CREATE INDEX idx_trabajador_ap_materno_upper 
    ON trabajador(UPPER(apmaterno));

-- Consulta de verificación de la vista
SELECT * 
FROM V_AUMENTOS_ESTUDIOS;

SELECT index_name, table_name, column_name 
FROM user_ind_columns 
WHERE table_name = 'TRABAJADOR' 
ORDER BY index_name;

--Búsqueda exacta por apellido materno

EXPLAIN PLAN FOR
SELECT 
    t.numrut, 
    t.nombre, 
    t.appaterno, 
    t.apmaterno, 
    i.nombre_isapre AS isapre
FROM trabajador t
JOIN isapre i 
  ON t.cod_isapre = i.cod_isapre
WHERE t.apmaterno = 'CASTILLO';

SELECT * 
FROM TABLE(DBMS_XPLAN.DISPLAY);

--UPPER(apmaterno)


EXPLAIN PLAN FOR
SELECT 
    t.numrut, 
    t.nombre, 
    t.appaterno, 
    t.apmaterno, 
    i.nombre_isapre AS isapre
FROM trabajador t
JOIN isapre i 
  ON t.cod_isapre = i.cod_isapre
WHERE UPPER(t.apmaterno) = 'CASTILLO';

SELECT * 
FROM TABLE(DBMS_XPLAN.DISPLAY);

COMMIT;

-- Fin script