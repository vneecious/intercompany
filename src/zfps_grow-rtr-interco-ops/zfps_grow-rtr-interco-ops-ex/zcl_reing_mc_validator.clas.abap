CLASS zcl_reing_mc_validator DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      ty_metric_code TYPE zreing_mcv_a-metric_code,
      ty_version_num TYPE zreing_mcv_a-version_num,
      ty_status      TYPE zreing_mcv_a-version_status.

    " BR-02 / BR-01: Verifica si una version especifica tiene contratos activos vinculados
    CLASS-METHODS check_version_in_use
      IMPORTING
        iv_metric_code   TYPE ty_metric_code
        iv_version_num   TYPE ty_version_num
      RETURNING
        VALUE(rv_in_use) TYPE abap_bool.

    " BR-02: Bloquea inactivacion si hay contratos activos en esa version
    CLASS-METHODS check_version_can_inactivate
      IMPORTING
        iv_metric_code    TYPE ty_metric_code
        iv_version_num    TYPE ty_version_num
      RETURNING
        VALUE(rv_blocked) TYPE abap_bool.

    " BR-03: Bloquea eliminacion si la metrica fue usada en PRGI
    CLASS-METHODS check_metric_used_in_prgi
      IMPORTING
        iv_metric_code TYPE ty_metric_code
      RETURNING
        VALUE(rv_used) TYPE abap_bool.

    " BR-01: Verifica si una metrica/version tiene contratos activos (bloquea edicion)
    CLASS-METHODS check_has_active_contracts
      IMPORTING
        iv_metric_code     TYPE ty_metric_code
        iv_version_num     TYPE ty_version_num
      RETURNING
        VALUE(rv_has_ct)   TYPE abap_bool.

ENDCLASS.

CLASS zcl_reing_mc_validator IMPLEMENTATION.

METHOD check_version_in_use.
  " Verifica si la version tiene contratos activos vinculados en CT V2
  " CT V2: zreing_ct2_met_a usa ct_uuid como FK a zreing_ct2_a
  SELECT SINGLE @abap_true
    FROM zreing_ct2_met_a AS cm
    INNER JOIN zreing_ct2_a AS ct
      ON ct~ct_uuid   = cm~ct_uuid
     AND ct~ct_status = 'A'
    WHERE cm~metric_code = @iv_metric_code
      AND cm~version_num = @iv_version_num
      AND cm~met_status  = 'AC'
    INTO @rv_in_use.
ENDMETHOD.

  METHOD check_version_can_inactivate.
    " BR-02: bloquea inactivacion si hay contratos activos
    rv_blocked = check_version_in_use(
      iv_metric_code = iv_metric_code
      iv_version_num = iv_version_num ).
  ENDMETHOD.

  METHOD check_metric_used_in_prgi.
    " BR-03: bloquea eliminacion si la metrica fue usada en PRGI
    " TODO Sprint 3: descomentar cuando exista tabla de ejecuciones PRGI
    rv_used = abap_false.
*    SELECT SINGLE @abap_true
*      FROM zreing_run_metric_a
*      WHERE metric_code = @iv_metric_code
*        AND run_status  = 'C'
*      INTO @rv_used.
  ENDMETHOD.

  METHOD check_has_active_contracts.
    " BR-01: para bloquear edicion de version con contratos activos
    rv_has_ct = check_version_in_use(
      iv_metric_code = iv_metric_code
      iv_version_num = iv_version_num ).
  ENDMETHOD.

ENDCLASS.
