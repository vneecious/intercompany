*----------------------------------------------------------------------*
* Created by     : equipo F4 (CONTAB)                                  *
* Date           : 14.07.2026                                          *
* Description    : Carga datos de prueba en ZREING_CA_LINE_A            *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Cargador de datos de prueba a partir del export de CA
* (CA_Export_062026). Genera lineas de calculo IC para probar la app
* CONTAB (Fase 4).
*
* Clase ejecutable Cloud (if_oo_adt_classrun): correr con F9 en ADT.
* No es un reporte SE38 porque el paquete es ABAP Cloud (PROG no
* permitido); esta es la variante Cloud-clean equivalente.
*
* calc_run_id fijo: CA062026TEST
* Prestadora: MUR (Uruguay). Receptoras: MLB/DAB/MCO/MLC segun fila.
* Status: se carga tal cual el export (SIM_OK / CALC / CONT).
*
* MODO: controlado por la constante GC_COMMIT.
*   GC_COMMIT = abap_false -> DRY RUN (solo lista lo que insertaria)
*   GC_COMMIT = abap_true  -> inserta realmente en la tabla
* Editar la constante y volver a ejecutar (F9).
*
* Re-ejecucion: si ya existen filas con ese calc_run_id, ABORTA (no
* duplica ni sobrescribe). Borrar manualmente si se quiere recargar.
*----------------------------------------------------------------------*
CLASS zcl_reing_ca_load_test DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS gc_run_id TYPE zreing_ca_line_a-calc_run_id VALUE 'CA062026TEST'.
    " Cambiar a abap_true para insertar realmente. abap_false = dry run.
    CONSTANTS gc_commit TYPE abap_bool VALUE abap_true.

    TYPES: BEGIN OF ty_src,
             matnr       TYPE zreing_ca_line_a-matnr,
             op_type     TYPE zreing_ca_line_a-op_type,
             bukrs_recv  TYPE zreing_ca_line_a-bukrs_recv,
             country     TYPE zreing_ca_line_a-country,
             prctr       TYPE prctr,
             share_pct   TYPE zreing_ca_line_a-share_pct,
             share_pais  TYPE zreing_ca_line_a-share_pais_pct,
             share_comb  TYPE zreing_ca_line_a-share_comb_pct,
             calc_amt    TYPE zreing_ca_line_a-calc_amt,
             bruto_amt   TYPE zreing_ca_line_a-bruto_amt,
             tax_amt     TYPE zreing_ca_line_a-tax_amt,
             net_amt     TYPE zreing_ca_line_a-net_amt,
             ct_currency TYPE zreing_ca_line_a-ct_currency,
             net_local   TYPE zreing_ca_line_a-net_local_amt,
             local_curr  TYPE zreing_ca_line_a-local_currency,
             exch_rate   TYPE zreing_ca_line_a-exch_rate,
             status      TYPE zreing_ca_line_a-line_status,
           END OF ty_src,
           ty_src_t TYPE STANDARD TABLE OF ty_src WITH EMPTY KEY.

    "! Devuelve las 13 lineas del export CA_Export_062026.
    METHODS get_source_data
      RETURNING VALUE(rt_src) TYPE ty_src_t.
ENDCLASS.


CLASS zcl_reing_ca_load_test IMPLEMENTATION.

  METHOD get_source_data.
    rt_src = VALUE #(
      " matnr / op / recv / ctry / prctr / sh% / shPais / shComb / calc / bruto / tax / net / ctCcy / netLocal / locCcy / fx / status
      ( matnr = 'ICSRV01' op_type = 'F' bukrs_recv = 'MLB' country = 'BR' prctr = '110'
        share_pct = '20' share_pais = '35' share_comb = '100'
        calc_amt = '24980.95' bruto_amt = '29389.35' tax_amt = '5657.45' net_amt = '19321.48'
        ct_currency = 'USD' net_local = '103346.58' local_curr = 'BRL' exch_rate = '5.34850' status = 'SIM_OK' )
      ( matnr = 'ICSRV01' op_type = 'F' bukrs_recv = 'MLB' country = 'BR' prctr = '120'
        share_pct = '15' share_pais = '35' share_comb = '100'
        calc_amt = '18769.05' bruto_amt = '22081.24' tax_amt = '4250.63' net_amt = '14520.44'
        ct_currency = 'USD' net_local = '77656.10' local_curr = 'BRL' exch_rate = '5.34850' status = 'SIM_OK' )
      ( matnr = 'ICSRV01' op_type = 'F' bukrs_recv = 'DAB' country = 'AR' prctr = '200'
        share_pct = '24' share_pais = '40' share_comb = '100'
        calc_amt = '30000.00' bruto_amt = '35294.12' tax_amt = '0.00' net_amt = '30000.00'
        ct_currency = 'USD' net_local = '31500000.00' local_curr = 'ARS' exch_rate = '1050.00' status = 'SIM_OK' )
      ( matnr = 'ICSRV01' op_type = 'F' bukrs_recv = 'DAB' country = 'AR' prctr = '210'
        share_pct = '16' share_pais = '40' share_comb = '100'
        calc_amt = '20000.00' bruto_amt = '23529.41' tax_amt = '0.00' net_amt = '20000.00'
        ct_currency = 'USD' net_local = '21000000.00' local_curr = 'ARS' exch_rate = '1050.00' status = 'SIM_OK' )
      ( matnr = 'ICSRV01' op_type = 'F' bukrs_recv = 'MCO' country = 'CO' prctr = '130'
        share_pct = '13.75' share_pais = '25' share_comb = '100'
        calc_amt = '17187.50' bruto_amt = '20220.59' tax_amt = '3841.91' net_amt = '13345.59'
        ct_currency = 'USD' net_local = '56051468.00' local_curr = 'COP' exch_rate = '4200.00' status = 'SIM_OK' )
      ( matnr = 'ICSRV01' op_type = 'F' bukrs_recv = 'MCO' country = 'CO' prctr = '200'
        share_pct = '11.25' share_pais = '25' share_comb = '100'
        calc_amt = '14062.50' bruto_amt = '16544.12' tax_amt = '3143.38' net_amt = '10919.12'
        ct_currency = 'USD' net_local = '45860314.00' local_curr = 'COP' exch_rate = '4200.00' status = 'SIM_OK' )
      ( matnr = 'ICSRV05' op_type = 'F' bukrs_recv = 'MLB' country = 'BR' prctr = ''
        share_pct = '30' share_pais = '30' share_comb = '100'
        calc_amt = '45000.00' bruto_amt = '45000.00' tax_amt = '8662.50' net_amt = '36337.50'
        ct_currency = 'USD' net_local = '194323.67' local_curr = 'BRL' exch_rate = '5.34850' status = 'CALC' )
      ( matnr = 'ICSRV05' op_type = 'F' bukrs_recv = 'DAB' country = 'AR' prctr = ''
        share_pct = '50' share_pais = '50' share_comb = '100'
        calc_amt = '75000.00' bruto_amt = '75000.00' tax_amt = '0.00' net_amt = '75000.00'
        ct_currency = 'USD' net_local = '78750000.00' local_curr = 'ARS' exch_rate = '1050.00' status = 'CALC' )
      ( matnr = 'ICSRV05' op_type = 'F' bukrs_recv = 'MUR' country = 'UY' prctr = ''
        share_pct = '20' share_pais = '20' share_comb = '100'
        calc_amt = '30000.00' bruto_amt = '30000.00' tax_amt = '0.00' net_amt = '30000.00'
        ct_currency = 'USD' net_local = '1230000.00' local_curr = 'UYU' exch_rate = '41.00000' status = 'CALC' )
      ( matnr = 'ICSRV01' op_type = 'D' bukrs_recv = 'MLB' country = 'BR' prctr = '110'
        share_pct = '20' share_pais = '35' share_comb = '100'
        calc_amt = '8745.14' bruto_amt = '10288.40' tax_amt = '1980.52' net_amt = '6765.52'
        ct_currency = 'USD' net_local = '36181.20' local_curr = 'BRL' exch_rate = '5.34850' status = 'CONT' )
      ( matnr = 'ICSRV01' op_type = 'D' bukrs_recv = 'MLB' country = 'BR' prctr = '120'
        share_pct = '15' share_pais = '35' share_comb = '100'
        calc_amt = '6567.36' bruto_amt = '7726.31' tax_amt = '1487.31' net_amt = '5079.15'
        ct_currency = 'USD' net_local = '27178.40' local_curr = 'BRL' exch_rate = '5.34850' status = 'CONT' )
      ( matnr = 'ICSRV01' op_type = 'D' bukrs_recv = 'DAB' country = 'AR' prctr = ''
        share_pct = '40' share_pais = '40' share_comb = '100'
        calc_amt = '17500.00' bruto_amt = '20588.24' tax_amt = '0.00' net_amt = '17500.00'
        ct_currency = 'USD' net_local = '18375000.00' local_curr = 'ARS' exch_rate = '1050.00' status = 'CONT' )
      ( matnr = 'ICSRV01' op_type = 'D' bukrs_recv = 'MLC' country = 'CL' prctr = ''
        share_pct = '25' share_pais = '25' share_comb = '100'
        calc_amt = '10937.50' bruto_amt = '12867.65' tax_amt = '0.00' net_amt = '10937.50'
        ct_currency = 'USD' net_local = '9843750.00' local_curr = 'CLP' exch_rate = '900.00000' status = 'CONT' ) ).
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.
    DATA lt_line TYPE STANDARD TABLE OF zreing_ca_line_a.
    DATA lv_lineno TYPE i.

    " ---- Chequeo de re-ejecucion: abortar si ya existen filas ----
    SELECT SINGLE @abap_true FROM zreing_ca_line_a
      WHERE calc_run_id = @gc_run_id
      INTO @DATA(lv_exists).
    IF lv_exists = abap_true.
      out->write( |ABORTADO: ya existen filas con calc_run_id { gc_run_id }.| ).
      out->write( |Borrelas antes de recargar.| ).
      RETURN.
    ENDIF.

    " ---- Armado de las lineas ----
    DATA(lt_src) = get_source_data( ).
    LOOP AT lt_src INTO DATA(ls_src).
      lv_lineno = lv_lineno + 1.
      APPEND VALUE zreing_ca_line_a(
        calc_run_id     = gc_run_id
        line_num        = lv_lineno
        ct_id           = 'IC-0012'
        matnr           = ls_src-matnr
        op_type         = ls_src-op_type
        op_instance_num = '001'
        bukrs_prest     = 'MUR'
        bukrs_recv      = ls_src-bukrs_recv
        country         = ls_src-country
        share_pct       = ls_src-share_pct
        share_pais_pct  = ls_src-share_pais
        share_comb_pct  = ls_src-share_comb
        base_amt        = ls_src-calc_amt
        calc_amt        = ls_src-calc_amt
        bruto_amt       = ls_src-bruto_amt
        tax_amt         = ls_src-tax_amt
        net_amt         = ls_src-net_amt
        ct_currency     = ls_src-ct_currency
        net_local_amt   = ls_src-net_local
        local_currency  = ls_src-local_curr
        exch_rate       = ls_src-exch_rate
        exch_rate_type  = 'M'
        has_pc_breakdown = COND #( WHEN ls_src-prctr IS NOT INITIAL THEN 'X' ELSE '' )
        line_status     = ls_src-status
        local_last_changed_at = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) )
      ) TO lt_line.
    ENDLOOP.

    " ---- Salida ----
    IF gc_commit = abap_false.
      out->write( |*** DRY RUN (GC_COMMIT = abap_false). No se escribe en BD. ***| ).
    ENDIF.
    out->write( |calc_run_id: { gc_run_id } | ).
    out->write( |Lineas: { lines( lt_line ) }| ).
    out->write( |------------------------------------------------------------| ).
    LOOP AT lt_line INTO DATA(ls_out).
      out->write( |{ ls_out-line_num ALPHA = OUT } { ls_out-op_type } | &&
                  |{ ls_out-bukrs_prest }->{ ls_out-bukrs_recv } { ls_out-country } | &&
                  |{ ls_out-matnr } PC:{ ls_out-has_pc_breakdown } | &&
                  |{ ls_out-net_amt } { ls_out-ct_currency } { ls_out-line_status }| ).
    ENDLOOP.
    out->write( |------------------------------------------------------------| ).

    " ---- Persistencia ----
    IF gc_commit = abap_true.
      INSERT zreing_ca_line_a FROM TABLE @lt_line.
      IF sy-subrc = 0.
        COMMIT WORK.
        out->write( |OK: { lines( lt_line ) } lineas insertadas en ZREING_CA_LINE_A.| ).
      ELSE.
        ROLLBACK WORK.
        out->write( |ERROR en INSERT. sy-subrc = { sy-subrc }| ).
      ENDIF.
    ELSE.
      out->write( |Para insertar: poner GC_COMMIT = abap_true y ejecutar de nuevo (F9).| ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.

