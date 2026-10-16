*----------------------------------------------------------------------*
* Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)     *
* Requirement N° : SDFPSINIC-23362                                    *
* Change ID      : V001                                               *
* Date           : 18.06.2026                                         *
* Description    : Reintegros ME — Fixes V001 (FX-XLS Plantilla Excel)*
* Transport      : DS4K9B5VNA                                         *
* Reference      : 5000047741                                         *
*----------------------------------------------------------------------*
CLASS zcl_reing_me_xls_hdl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " V001 (CC) - ME-12 (Delta v2)
    METHODS export_template
      IMPORTING iv_period_year         TYPE zreing_me_h_a-period_year  OPTIONAL
                iv_period_month        TYPE zreing_me_h_a-period_month OPTIONAL
                iv_metric_code         TYPE zreing_me_h_a-metric_code  OPTIONAL
      RETURNING VALUE(rv_file_content) TYPE xstring.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_reing_me_xls_hdl IMPLEMENTATION.

  METHOD export_template.
    " V001 (CC) - ME-12 (Delta v2)
    TYPES:
      BEGIN OF ty_saved_value,
        metric_code   TYPE zreing_me_h_a-metric_code,
        bukrs         TYPE zreing_me_i_a-bukrs,
        campana       TYPE zreing_me_i_a-campana,
        allocation    TYPE zreing_me_i_a-allocation,
        prctr         TYPE zreing_me_i_a-prctr,
        role_category TYPE zreing_me_i_a-role_category,
        me_value      TYPE zreing_me_i_a-me_value,
      END OF ty_saved_value,
      tt_saved_value TYPE HASHED TABLE OF ty_saved_value
        WITH UNIQUE KEY metric_code bukrs campana allocation prctr role_category.

    DATA(lo_write) = xco_cp_xlsx=>document->empty( )->write_access( ).
    DATA(lo_sheet) = lo_write->get_workbook( )->worksheet->at_position( 1 ).
    DATA(lo_cursor) = lo_sheet->cursor(
      io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
      io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( 1 ) ).

    lo_cursor->get_cell( )->value->write_from( 'Metrica' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Sociedad' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Campana' ).
    " Mod 25.09.2026 EXT_AGFAGINA - DF-553: "Asignacion" -> "Allocation". El
    " importador acepta los dos titulos, asi que los templates ya descargados
    " con el titulo viejo siguen subiendo.
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Allocation' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'CeBe' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Categoria Gasto' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Valor' ).

    " Begin Mod 04.09.2026 EXT_AGFAGINA - soporte "Todas las metricas".
    " El periodo sigue siendo obligatorio, pero la metrica pasa a ser opcional de
    " verdad: cuando llega vacia, el template se genera con TODAS las metricas
    " activas del periodo en una sola hoja, distinguidas por la columna A.
    " Se mantiene el mismo layout de 7 columnas, asi que el archivo sigue siendo
    " importable tal cual por ZCL_REING_ME_UPLOAD_HDL.
    " El filtro se resuelve con un rango: vacio, la condicion no restringe.
    IF iv_period_year IS INITIAL
      OR iv_period_month IS INITIAL.
      rv_file_content = lo_write->get_file_content( ).
      RETURN.
    ENDIF.

    " Begin Mod 15.09.2026 EXT_AGFAGINA - normalizar el codigo de metrica (tracker 75).
    " Sintoma: eligiendo UNA metrica el template bajaba vacio; con "Todas" bajaba bien.
    " Verificado en TS4 que la configuracion estaba completa (M-0014 activa, IC-0016
    " vigente en 12/2025, 28 receptoras activas con el mismo material), o sea que el
    " SELECT tenia que devolver filas: el problema es el valor que llega en el
    " parametro, no los datos.
    " METRIC_CODE es CHAR(6) y el desplegable muestra el texto completo
    " ("M-0014 - Nomina internos Meli - IT - Git Hub (v1)"). Cualquier cosa que
    " llegue con espacios, en minuscula o con texto adicional queda truncada a 6
    " caracteres y no coincide con nada, y como el filtro es EQ, el resultado es 0
    " filas sin ningun mensaje. Con "Todas" el parametro viene vacio, el rango queda
    " vacio y la condicion no restringe: por eso ese caso si funcionaba.
    " Se normaliza: se quitan blancos, se pasa a mayuscula y se corta en el primer
    " separador, de modo que "m-0014 - nomina..." y " M-0014 " resuelven igual.
    DATA lv_metric TYPE zreing_me_h_a-metric_code.
    CLEAR lv_metric.
    IF iv_metric_code IS NOT INITIAL.
      DATA(lv_raw_metric) = to_upper( condense( CONV string( iv_metric_code ) ) ).
      SPLIT lv_raw_metric AT space  INTO DATA(lv_part) DATA(lv_ignore1).
      SPLIT lv_part       AT '–'    INTO lv_part DATA(lv_ignore2).
      SPLIT lv_part       AT '('    INTO lv_part DATA(lv_ignore3).
      lv_metric = condense( lv_part ).
    ENDIF.

    DATA lr_metric TYPE RANGE OF zreing_me_h_a-metric_code.
    IF lv_metric IS NOT INITIAL.
      lr_metric = VALUE #( ( sign = 'I' option = 'EQ' low = lv_metric ) ).
    ENDIF.
    " End Mod 15.09.2026 EXT_AGFAGINA
    " End Mod 04.09.2026 EXT_AGFAGINA

    DATA(lv_first_day) = CONV d( |{ iv_period_year }{ iv_period_month }01| ).
    DATA(lv_last_day) = lv_first_day.
    lv_last_day = lv_last_day + 31.
    lv_last_day = lv_last_day - ( lv_last_day+6(2) ).

    SELECT DISTINCT
           met~metric_code   AS metric_code,
           rec~rec_bukrs     AS bukrs,
           rec~campana       AS campana,
           rec~allocation    AS allocation,
           rec~prctr         AS prctr,
           rec~role_category AS role_category,
           " Mod 25.09.2026 EXT_AGFAGINA - DF-553/554: nombre de la metrica, de la
           " version asignada al contrato. Se muestra junto al codigo en la
           " columna A ("M-0016 - S&T"); el codigo se conserva porque los
           " nombres NO son unicos (M-0007 y M-0009 se llaman igual) y el
           " importador necesita una clave sin ambiguedad.
           mcv~metric_desc   AS metric_desc
      FROM zreing_ct2_a AS con
      INNER JOIN zreing_ct2_mat_a AS mat
        ON mat~ct_uuid = con~ct_uuid
      INNER JOIN zreing_ct2_met_a AS met
        ON met~ct_uuid = mat~ct_uuid
       AND met~mat_uuid = mat~mat_uuid
      INNER JOIN zreing_ct2_rec_a AS rec
        ON rec~ct_uuid = mat~ct_uuid
       AND rec~mat_uuid = mat~mat_uuid
      LEFT OUTER JOIN zreing_mcv_a AS mcv
        ON mcv~metric_code = met~metric_code
       AND mcv~version_num = met~version_num
      WHERE con~ct_status = 'AC'
        AND con~valid_from <= @lv_last_day
        AND con~valid_to >= @lv_first_day
        AND met~met_status = 'AC'
        AND met~metric_code IN @lr_metric
        AND rec~rec_status = 'AC'
      ORDER BY metric_code, bukrs, campana, allocation, prctr, role_category
      INTO TABLE @DATA(lt_config).

    IF lt_config IS INITIAL.
      rv_file_content = lo_write->get_file_content( ).
      RETURN.
    ENDIF.

    " Begin Mod 15.09.2026 EXT_AGFAGINA - la columna Valor sale SIEMPRE en 0.
    " Definicion funcional (tracker 76): el template no debe traer los valores ya
    " cargados del periodo. Antes se prellenaba con lo que hubiera en
    " ZREING_ME_I_A, lo que generaba dos problemas:
    "   - confundia: los valores cargados coincidian con los shares en las pruebas
    "     y parecia que el template bajaba porcentajes (tracker 75 original);
    "   - al reimportar sin editar, se reescribian los mismos valores en silencio.
    " Se elimino el SELECT de valores guardados y su tabla de indice: ya no hacen
    " falta. La celda se escribe con 0 numerico, que mantiene el archivo importable
    " tal cual y le marca al usuario que tiene que completarla.
    LOOP AT lt_config ASSIGNING FIELD-SYMBOL(<ls_config>).
      " Fix (28.08.2026 | EXT_AGFAGINA) - el template se generaba con valores
      " padeados (campos CHAR de largo fijo) y el importador los rechazaba:
      " CeBe llegaba como '199       ' y fallaba el chequeo numerico.
      " Se aplica condense( ) a todos los valores de texto.
      DATA(lv_prctr) = condense( |{ <ls_config>-prctr ALPHA = OUT }| ).
      lo_cursor = lo_sheet->cursor(
        io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
        io_row = xco_cp_xlsx=>coordinate->for_numeric_value( sy-tabix + 1 ) ).

      " Mod 04.09.2026 EXT_AGFAGINA: se escribe la metrica de la PROPIA fila, no el
      " parametro. Con "Todas" el parametro viene vacio y la columna A quedaria en
      " blanco, lo que hace el archivo no importable.
      " Mod 25.09.2026 EXT_AGFAGINA - DF-553/554: la columna A lleva codigo y nombre
      " ("M-0016 - S&T"). El importador toma el codigo del primer bloque antes del
      " espacio, asi que tambien sigue aceptando archivos con solo el codigo.
      DATA(lv_metric_cell) = COND string(
        WHEN <ls_config>-metric_desc IS INITIAL
        THEN condense( CONV string( <ls_config>-metric_code ) )
        ELSE |{ condense( CONV string( <ls_config>-metric_code ) ) } - { condense( CONV string( <ls_config>-metric_desc ) ) }| ).
      lo_cursor->get_cell( )->value->write_from( lv_metric_cell ).
      lo_cursor->move_right( )->get_cell( )->value->write_from(
        condense( CONV string( <ls_config>-bukrs ) ) ).
      lo_cursor->move_right( )->get_cell( )->value->write_from(
        condense( CONV string( <ls_config>-campana ) ) ).
      lo_cursor->move_right( )->get_cell( )->value->write_from(
        condense( CONV string( <ls_config>-allocation ) ) ).
      lo_cursor->move_right( )->get_cell( )->value->write_from( lv_prctr ).
      lo_cursor->move_right( )->get_cell( )->value->write_from(
        condense( CONV string( <ls_config>-role_category ) ) ).

      " Columna G (Valor): siempre 0 numerico. El 0 mantiene la celda tipada como
      " numero y no genera registros al importar (import_file ignora monto 0 y lo
      " informa como aviso), asi que sirve de recordatorio de completarla.
      DATA lv_me_value TYPE zreing_me_i_a-me_value.
      CLEAR lv_me_value.
      lo_cursor->move_right( )->get_cell( )->value->write_from( lv_me_value ).
    ENDLOOP.
    " End Mod 15.09.2026 EXT_AGFAGINA

    rv_file_content = lo_write->get_file_content( ).
  ENDMETHOD.

ENDCLASS.
