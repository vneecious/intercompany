CLASS zcl_interco_costelem_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.
    CLASS-METHODS get_instance
      RETURNING VALUE(ro_instance) TYPE REF TO zcl_interco_costelem_reader.

    METHODS is_ceco_relevant
      IMPORTING
        !iv_kokrs          TYPE kokrs
        !iv_saknr          TYPE saknr
        !iv_keydate        TYPE sy-datum DEFAULT sy-datum
      RETURNING
        VALUE(rv_relevant) TYPE abap_bool.

  PRIVATE SECTION.
    CLASS-DATA go_instance TYPE REF TO zcl_interco_costelem_reader.

    TYPES:
      BEGIN OF ty_ceco_account,
        kokrs TYPE kokrs,
        saknr TYPE saknr,
      END OF ty_ceco_account.

    DATA:
      mt_ceco_accounts TYPE HASHED TABLE OF ty_ceco_account WITH UNIQUE KEY kokrs saknr,
      mt_kokrs_loaded  TYPE HASHED TABLE OF kokrs WITH UNIQUE KEY table_line.

    METHODS load_buffer_for_kokrs
      IMPORTING
        !iv_kokrs   TYPE kokrs
        !iv_keydate TYPE sy-datum.
ENDCLASS.


CLASS zcl_interco_costelem_reader IMPLEMENTATION.

  METHOD get_instance.
    ro_instance = COND #( WHEN zcl_interco_costelem_reader=>go_instance IS BOUND
                           THEN zcl_interco_costelem_reader=>go_instance
                           ELSE NEW zcl_interco_costelem_reader( ) ).
    go_instance = ro_instance.
  ENDMETHOD.

  METHOD is_ceco_relevant.
* Ini EXT_OSCUGALD 09.09.2026 - Determinar si una cuenta requiere CeCo, via maestro CO real
* Motivo: reemplaza el criterio de RECL_COMP (fix 07.09.2026) que forzaba CeCo en
* glaccount2 para CUALQUIER propuesta con providercountry = 'BR' -> era demasiado
* amplio y rompio ICSRV53 (glaccount2 = cuenta de ingreso, no necesita CeCo) con KI261.
* El criterio real que usa SAP para exigir CeCo es la categoria del cost element de
* ESA cuenta puntual (KATYP/CELEM_CATEGORY: '01' = costes primarios -> exige objeto
* CO; '11' = ingresos y el resto -> no exige). Ese dato no esta disponible via un CDS
* o tabla liberada para consumo de cliente (I_CostElement y CSKB estan clasificadas
* 'notToBeReleased' / Clean Core nivel C) -> se lee via la BAPI oficial liberada
* BAPI_COSTELEM_GETLIST, filtrando category = '01'. Se buffer-iza por area de CO
* (1 llamada BAPI por KOKRS por ejecucion, no por item de la propuesta).
*Ini EXT_OSCUGALD 09.09.2026 - ATC fix: NonLocal Nested Reading DB OP
* ANTES: este metodo recibia iv_bukrs y resolvia KOKRS internamente (SELECT contra
* I_CompanyCode), pero segunia marcando el chequeo porque se llama una vez por
* item dentro del loop de RECL_COMP. FIX: el wrapper deja de leer DB por su cuenta;
* recibe iv_kokrs ya resuelto por el llamador (RECL_COMP lo resuelve UNA vez, antes
* del loop, mismo patron que lt_cs_pandlids_rc). El wrapper queda limitado a la
* BAPI (bufferizada por KOKRS).
    IF NOT line_exists( mt_kokrs_loaded[ table_line = iv_kokrs ] ).
      load_buffer_for_kokrs( iv_kokrs = iv_kokrs iv_keydate = iv_keydate ).
    ENDIF.

    rv_relevant = xsdbool( line_exists( mt_ceco_accounts[ kokrs = iv_kokrs saknr = iv_saknr ] ) ).
*Fin EXT_OSCUGALD 09.09.2026 - ATC fix: NonLocal Nested Reading DB OP
* Fin EXT_OSCUGALD 09.09.2026 - Determinar si una cuenta requiere CeCo, via maestro CO real
  ENDMETHOD.




  METHOD load_buffer_for_kokrs.
    DATA lt_list TYPE STANDARD TABLE OF bapi1030_celist.
    DATA lt_ret  TYPE STANDARD TABLE OF bapiret2.

    INSERT iv_kokrs INTO TABLE mt_kokrs_loaded.

* Traer, para esta area de CO, solo las cuentas categoria '01' (costes primarios,
* las unicas que exigen objeto CO al contabilizar). Categoria '11' (ingresos) y
* cualquier otra quedan afuera a proposito: esas NO deben llevar CeCo.
    CALL FUNCTION 'BAPI_COSTELEM_GETLIST'
      EXPORTING
        coarea     = iv_kokrs
        date       = iv_keydate
        category   = '01'
        categoryto = '01'
      TABLES
        costelementlist = lt_list
        return          = lt_ret.

    LOOP AT lt_list INTO DATA(ls_list).
      INSERT VALUE #( kokrs = iv_kokrs saknr = ls_list-cost_elem ) INTO TABLE mt_ceco_accounts.
    ENDLOOP.
  ENDMETHOD.


ENDCLASS.

