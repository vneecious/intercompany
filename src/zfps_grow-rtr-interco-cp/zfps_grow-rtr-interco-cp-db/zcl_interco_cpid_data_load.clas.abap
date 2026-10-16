CLASS zcl_interco_cpid_data_load DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .

    TYPES:
      ty_cpd  TYPE STANDARD TABLE OF zfi_a_intrc_cpd,
      ty_cpdl TYPE STANDARD TABLE OF zfi_a_intrc_cpdl,
      ty_cpid TYPE STANDARD TABLE OF zfi_a_intrc_cpid.
*      ty_cpdf TYPE STANDARD TABLE OF zfi_a_intrc_cpdf.

    CLASS-METHODS clean_table .
    CLASS-METHODS load_data
      IMPORTING
        !it_cpid      TYPE ty_cpid
*        !it_cpdf      TYPE ty_cpdf
      RETURNING
        VALUE(rv_len) TYPE int4 .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_interco_cpid_data_load IMPLEMENTATION.
  METHOD clean_table.
    DATA: lt_to_insert_cpd  TYPE STANDARD TABLE OF zfi_a_intrc_cpd,
          lt_to_insert_cpdl TYPE STANDARD TABLE OF zfi_a_intrc_cpdl,
          lt_to_insert_d    TYPE STANDARD TABLE OF zfi_a_intrc_cpid.
*          lt_to_insert_f    TYPE STANDARD TABLE OF zfi_a_intrc_cpdf.

*    SELECT FROM zfi_a_intrc_cpid AS _doc
*  LEFT JOIN zfi_a_intrc_dtyp AS _dtyp ON _doc~documenttype EQ _dtyp~dtyp_id
*                                     AND _dtyp~language_code EQ 'S'
*  FIELDS
*  _doc~client,
*  _doc~id,
*  _doc~item_id,
*  _doc~itembasis_id,
*  _doc~itemcalc_id,
*  _doc~documenttype,
**  _dtyp~dtyp_name,
*  MAX( _doc~documentkey ) AS documentkey,
*  MAX( _doc~parentdocumenttype ) AS parentdocumenttype,
*  MAX( _doc~parentdocumentkey ) AS parentdocumentkey,
*  MAX( _doc~cat_id ) AS cat_id,
*  MAX( _doc~isadjustment ) AS isadjustment,
*  MAX( _doc~status ) AS status,
*  MAX( _doc~createdby ) AS createdby,
*  MAX( _doc~createdat ) AS createdat
*  GROUP BY
*  _doc~client,
*  _doc~id,
*  _doc~item_id,
*  _doc~itembasis_id,
*  _doc~itemcalc_id,
*  _doc~documenttype
**  _dtyp~dtyp_name
* HAVING COUNT( * ) > 1
*  ORDER BY
*  _doc~client,
*  _doc~id,
*  _doc~item_id,
*  _doc~itembasis_id,
*  _doc~itemcalc_id,
*  _doc~documenttype,
**  _dtyp~dtyp_name,
*  createdat
* INTO CORRESPONDING FIELDS OF TABLE @lt_to_insert_d.
*    IF sy-subrc EQ 0.
*      SELECT FROM zfi_a_intrc_cpid AS _doc
*LEFT JOIN zfi_a_intrc_cpdf AS _flow ON
*_doc~id           EQ _flow~id
*AND _doc~item_id      EQ _flow~item_id
*AND _doc~itembasis_id EQ _flow~itembasis_id
*AND _doc~itemcalc_id  EQ _flow~itemcalc_id
*AND _doc~documenttype EQ _flow~documenttype
*AND _doc~documentkey  EQ _flow~documentkey
*FIELDS
*_doc~client                     AS client,
*_doc~id                         AS id,
*_doc~item_id                    AS item_id,
*_doc~itembasis_id               AS itembasis_id,
*_doc~itemcalc_id                AS itemcalc_id,
*_doc~documenttype               AS documenttype,
*MAX( _doc~documentkey )         AS documentkey,
*MAX( _doc~parentdocumenttype )  AS parentdocumenttype,
*MAX( _doc~parentdocumentkey )   AS parentdocumentkey,
*MAX( _doc~cat_id )              AS cat_id,
*MAX( _doc~isadjustment )        AS isadjustment,
*MAX( _doc~status )              AS status,
*MAX( _doc~createdby )           AS createdby,
*MAX( _doc~createdat )           AS createdat,
*_flow~tstmpl,
*_flow~type,
*_flow~message
*GROUP BY
*_doc~client,
*_doc~id,
*_doc~item_id,
*_doc~itembasis_id,
*_doc~itemcalc_id,
*_doc~documenttype,
*_flow~tstmpl,
*_flow~type,
*_flow~message
*HAVING COUNT( * ) > 1
*     INTO CORRESPONDING FIELDS OF TABLE @lt_to_insert_f.
*      IF sy-subrc EQ 0.
*        DELETE FROM zfi_a_intrc_cpdl WHERE id IS NOT INITIAL.
*        DELETE FROM zfi_a_intrc_cpdl WHERE id IS  INITIAL.
*        DELETE FROM zfi_a_intrc_cpdf WHERE id IS NOT INITIAL.
*        DELETE FROM zfi_a_intrc_cpdf WHERE id IS  INITIAL.
*        INSERT zfi_a_intrc_cpdf FROM TABLE @lt_to_insert_f.
*        COMMIT WORK.
*      ENDIF.
    DATA lv_id TYPE zfi_a_intrc_cph-id.
    DATA lv_DelAll TYPE c VALUE abap_false.
    IF lv_DelAll EQ abap_true.
      DELETE FROM zfi_a_intrc_cpd WHERE id IS NOT INITIAL.
      DELETE FROM zfi_a_intrc_cpd WHERE id IS  INITIAL.
      DELETE FROM zfi_a_intrc_cpid WHERE id IS NOT INITIAL.
      DELETE FROM zfi_a_intrc_cpid WHERE id IS  INITIAL.
      DELETE FROM zfi_a_intrc_cpdl WHERE id IS NOT INITIAL.
      DELETE FROM zfi_a_intrc_cpdl WHERE id IS  INITIAL.
    ELSE.
      DELETE FROM zfi_a_intrc_cpd WHERE id EQ @lv_id.
      DELETE FROM zfi_a_intrc_cpid WHERE id EQ @lv_id.
      DELETE FROM zfi_a_intrc_cpdl WHERE id EQ @lv_id.
    ENDIF.
*      INSERT zfi_a_intrc_cpid FROM TABLE @lt_to_insert_d.
    COMMIT WORK.
*    ENDIF.
  ENDMETHOD.

  METHOD load_data.
    DATA: lt_cpid         TYPE ty_cpid,
*          lt_cpdf         TYPE ty_cpdf,
          lt_cpd          TYPE ty_cpd,
          lt_cpdl         TYPE ty_cpdl,
          ls_cpd          TYPE zfi_a_intrc_cpd,
          ls_cpdl         TYPE zfi_a_intrc_cpdl,
          ls_cpid         TYPE zfi_a_intrc_cpid,
*          ls_cpdf         TYPE zfi_a_intrc_cpdf,
          ln_dockey       TYPE n LENGTH 12,
          ln_parentdockey TYPE n LENGTH 12,
          ld_tmst         TYPE abp_creation_tstmpl.

    lt_cpid = it_cpid.
    GET TIME STAMP FIELD ld_tmst.
*    ld_tmst = cl_abap_context_info=>get_system_date( ).

    SELECT id, item_id, itembasis_id, itemcalc_id FROM zfi_a_intrc_cpic
    WHERE id IS NOT INITIAL
    INTO TABLE @DATA(lt_cpic) UP TO 100 ROWS.
*    SELECT SINGLE id, item_id FROM zfi_a_intrc_cpi INTO @DATA(ls_cph).

    LOOP AT lt_cpic ASSIGNING FIELD-SYMBOL(<ls_cpic>).
      "Interdivison
      ln_dockey = ln_dockey + 1.
      CLEAR: ls_cpid.
      MOVE-CORRESPONDING <ls_cpic> TO ls_cpid.
      ls_cpid-documenttype = 10."Interdivision
      ls_cpid-documentkey = ln_dockey.
*      ls_cpid-parentdocumenttype = 1.
*      ls_cpid-parentdocumentkey = 1.
      ls_cpid-cat_id = 1."Interdivisión
      ls_cpid-isadjustment = abap_true.
      ls_cpid-status = 'C'."Commited
      ls_cpid-createdby = cl_abap_context_info=>get_user_technical_name( ).
      ls_cpid-createdat = ld_tmst.
      APPEND ls_cpid TO lt_cpid.
      MOVE-CORRESPONDING ls_cpid TO ls_cpd.
      APPEND ls_cpd TO lt_cpd.
*      MOVE-CORRESPONDING ls_cpid TO ls_cpdf.
*      ls_cpdf-tstmpl = ld_tmst.
*      ls_cpdf-type = 'S'."Sucess
*      ls_cpdf-message = 'Documento Interdivision dummy satisfactorio'.
*      APPEND ls_cpdf TO lt_cpdf.
      MOVE-CORRESPONDING ls_cpid TO ls_cpdl.
      ls_cpdl-msgid = 'HRTRAINING'.
      ls_cpdl-msgno = 1.
      ls_cpdl-msgv1 = 'test1'.
      ls_cpdl-msgv2 = 'test2'.
      ls_cpdl-msgv3 = 'test3'.
      ls_cpdl-msgv4 = 'test4'.
      ls_cpdl-spras = 'E'.
      ls_cpdl-message = 'Test Message'.
      APPEND ls_cpdl TO lt_cpdl.

      "Interdivison
      ln_dockey = ln_dockey + 1.
      CLEAR: ls_cpid.
      MOVE-CORRESPONDING <ls_cpic> TO ls_cpid.
      ls_cpid-documenttype = 10."Interdivison
      ls_cpid-documentkey = ln_dockey.
*      ls_cpid-parentdocumenttype = 10.
*      ls_cpid-parentdocumentkey = 10.
      ls_cpid-cat_id = 1."Interdivisión
      ls_cpid-isadjustment = abap_false.
      ls_cpid-status = 'E'."Error
      ls_cpid-createdby = cl_abap_context_info=>get_user_technical_name( ).
      ls_cpid-createdat = ld_tmst.
      APPEND ls_cpid TO lt_cpid.
      MOVE-CORRESPONDING ls_cpid TO ls_cpd.
      APPEND ls_cpd TO lt_cpd.
*      MOVE-CORRESPONDING ls_cpid TO ls_cpdf.
*      ls_cpdf-tstmpl = ld_tmst.
*      ls_cpdf-type = 'E'."Error
*      ls_cpdf-message = 'Documento Interdivision dummy erroneo'.
*      APPEND ls_cpdf TO lt_cpdf.
      MOVE-CORRESPONDING ls_cpid TO ls_cpdl.
      ls_cpdl-msgid = 'HRTRAINING'.
      ls_cpdl-msgno = 1.
      ls_cpdl-msgv1 = 'test1'.
      ls_cpdl-msgv2 = 'test2'.
      ls_cpdl-msgv3 = 'test3'.
      ls_cpdl-msgv4 = 'test4'.
      ls_cpdl-spras = 'S'.
      ls_cpdl-message = 'Mensaje de prueba'.
      APPEND ls_cpdl TO lt_cpdl.

      "SalesOrder
      ln_dockey = ln_dockey + 1.
      CLEAR: ls_cpid.
      MOVE-CORRESPONDING <ls_cpic> TO ls_cpid.
      ls_cpid-documenttype = 20."SalesOrder
      ls_cpid-documentkey = ln_dockey.
*      ls_cpid-parentdocumenttype = 1.
*      ls_cpid-parentdocumentkey = 1.
      ls_cpid-cat_id = 2."Pedidos
      ls_cpid-isadjustment = abap_true.
      ls_cpid-status = 'E'."Error
      ls_cpid-createdby = cl_abap_context_info=>get_user_technical_name( ).
      ls_cpid-createdat = ld_tmst.
      APPEND ls_cpid TO lt_cpid.
      MOVE-CORRESPONDING ls_cpid TO ls_cpd.
      APPEND ls_cpd TO lt_cpd.
*      MOVE-CORRESPONDING ls_cpid TO ls_cpdf.
*      ls_cpdf-tstmpl = ld_tmst.
*      ls_cpdf-type = 'E'."Error
*      ls_cpdf-message = 'Documento SalesOrder dummy erroneo'.
*      APPEND ls_cpdf TO lt_cpdf.
      MOVE-CORRESPONDING ls_cpid TO ls_cpdl.
      ls_cpdl-msgid = 'HRTRAINING'.
      ls_cpdl-msgno = 1.
      ls_cpdl-msgv1 = 'test1'.
      ls_cpdl-msgv2 = 'test2'.
      ls_cpdl-msgv3 = 'test3'.
      ls_cpdl-msgv4 = 'test4'.
      ls_cpdl-spras = 'P'.
      ls_cpdl-message = 'Test Message'.
      APPEND ls_cpdl TO lt_cpdl.

      "SalesOrder
*      ln_dockey = ln_dockey + 1.
      CLEAR: ls_cpid.
      MOVE-CORRESPONDING <ls_cpic> TO ls_cpid.
      ls_cpid-documenttype = 20."SalesOrder
      ls_cpid-documentkey = ln_dockey.
*      ls_cpid-parentdocumenttype = 1.
*      ls_cpid-parentdocumentkey = 1.
      ls_cpid-cat_id = 2."Pedidos
      ls_cpid-isadjustment = abap_true.
      ls_cpid-status = 'C'."Commited
      ls_cpid-createdby = cl_abap_context_info=>get_user_technical_name( ).
      ls_cpid-createdat = ld_tmst.
      APPEND ls_cpid TO lt_cpid.
      MOVE-CORRESPONDING ls_cpid TO ls_cpd.
      APPEND ls_cpd TO lt_cpd.
*      MOVE-CORRESPONDING ls_cpid TO ls_cpdf.
*      ls_cpdf-tstmpl = ld_tmst.
*      ls_cpdf-type = 'S'."Success
*      ls_cpdf-message = 'Documento SalesOrder dummy satisfactorio'.
*      APPEND ls_cpdf TO lt_cpdf.
      MOVE-CORRESPONDING ls_cpid TO ls_cpdl.
      ls_cpdl-msgid = 'HRTRAINING'.
      ls_cpdl-msgno = 1.
      ls_cpdl-msgv1 = 'test1'.
      ls_cpdl-msgv2 = 'test2'.
      ls_cpdl-msgv3 = 'test3'.
      ls_cpdl-msgv4 = 'test4'.
      ls_cpdl-spras = 'E'.
      ls_cpdl-message = 'Test Message 2'.
      APPEND ls_cpdl TO lt_cpdl.

      "BillingDocument
      CLEAR: ls_cpid.
      ln_parentdockey = ln_dockey.
      ln_dockey = ln_dockey + 1.
      MOVE-CORRESPONDING <ls_cpic> TO ls_cpid.
      ls_cpid-documenttype = 30."BillingDocument
      ls_cpid-documentkey = ln_dockey.
      ls_cpid-parentdocumenttype = 20."SalesOrder
      ls_cpid-parentdocumentkey = ln_parentdockey.
      ls_cpid-cat_id = 3."Factura
      ls_cpid-isadjustment = abap_true.
      ls_cpid-status = 'E'."Error
      ls_cpid-createdby = cl_abap_context_info=>get_user_technical_name( ).
      ls_cpid-createdat = ld_tmst.
      APPEND ls_cpid TO lt_cpid.
      MOVE-CORRESPONDING ls_cpid TO ls_cpd.
      APPEND ls_cpd TO lt_cpd.
*      MOVE-CORRESPONDING ls_cpid TO ls_cpdf.
*      ls_cpdf-tstmpl = ld_tmst.
*      ls_cpdf-type = 'E'."Error
*      ls_cpdf-message = 'Documento BillingDocument dummy erroneo'.
*      APPEND ls_cpdf TO lt_cpdf.
      MOVE-CORRESPONDING ls_cpid TO ls_cpdl.
      ls_cpdl-msgid = 'HRTRAINING'.
      ls_cpdl-msgno = 1.
      ls_cpdl-msgv1 = 'test1'.
      ls_cpdl-msgv2 = 'test2'.
      ls_cpdl-msgv3 = 'test3'.
      ls_cpdl-msgv4 = 'test4'.
      ls_cpdl-spras = 'S'.
      ls_cpdl-message = 'Mensaje de prueba'.
      APPEND ls_cpdl TO lt_cpdl.

      "BillingDocument
      CLEAR: ls_cpid.
*      ln_parentdockey = ln_dockey.
      ln_dockey = ln_dockey + 1.
      MOVE-CORRESPONDING <ls_cpic> TO ls_cpid.
      ls_cpid-documenttype = 30."BillingDocument
      ls_cpid-documentkey = ln_dockey.
      ls_cpid-parentdocumenttype = 20."SalesOrder
      ls_cpid-parentdocumentkey = ln_parentdockey.
      ls_cpid-cat_id = 3."Factura
      ls_cpid-isadjustment = abap_true.
      ls_cpid-status = 'C'."Commited
      ls_cpid-createdby = cl_abap_context_info=>get_user_technical_name( ).
      ls_cpid-createdat = ld_tmst.
      APPEND ls_cpid TO lt_cpid.
      MOVE-CORRESPONDING ls_cpid TO ls_cpd.
      APPEND ls_cpd TO lt_cpd.
*      MOVE-CORRESPONDING ls_cpid TO ls_cpdf.
*      ls_cpdf-tstmpl = ld_tmst.
*      ls_cpdf-type = 'S'."Success
*      ls_cpdf-message = 'Documento BillingDocument dummy satisfactorio'.
*      APPEND ls_cpdf TO lt_cpdf.
      MOVE-CORRESPONDING ls_cpid TO ls_cpdl.
      ls_cpdl-msgid = 'HRTRAINING'.
      ls_cpdl-msgno = 1.
      ls_cpdl-msgv1 = 'test1'.
      ls_cpdl-msgv2 = 'test2'.
      ls_cpdl-msgv3 = 'test3'.
      ls_cpdl-msgv4 = 'test4'.
      ls_cpdl-spras = 'P'.
      ls_cpdl-message = 'Test Message 2'.
      APPEND ls_cpdl TO lt_cpdl.

      "PurchaseOrder
      CLEAR: ls_cpid.
      ln_dockey = ln_dockey + 1.
      MOVE-CORRESPONDING <ls_cpic> TO ls_cpid.
      ls_cpid-documenttype = 40."PurchaseOrder
      ls_cpid-documentkey = ln_dockey.
*      ls_cpid-parentdocumenttype = 1.
*      ls_cpid-parentdocumentkey = 1.
      ls_cpid-cat_id = 2."Pedidos
      ls_cpid-isadjustment = abap_true.
      ls_cpid-status = 'E'."Error
      ls_cpid-createdby = cl_abap_context_info=>get_user_technical_name( ).
      ls_cpid-createdat = ld_tmst.
      APPEND ls_cpid TO lt_cpid.
      MOVE-CORRESPONDING ls_cpid TO ls_cpd.
      APPEND ls_cpd TO lt_cpd.
*      MOVE-CORRESPONDING ls_cpid TO ls_cpdf.
*      ls_cpdf-tstmpl = ld_tmst.
*      ls_cpdf-type = 'E'."Error
*      ls_cpdf-message = 'Documento PurchaseOrder dummy erroneo'.
*      APPEND ls_cpdf TO lt_cpdf.
      MOVE-CORRESPONDING ls_cpid TO ls_cpdl.
      APPEND ls_cpdl TO lt_cpdl.

      "PurchaseOrder
      CLEAR: ls_cpid.
      ln_dockey = ln_dockey + 1.
      MOVE-CORRESPONDING <ls_cpic> TO ls_cpid.
      ls_cpid-documenttype = 40."PurchaseOrder
      ls_cpid-documentkey = ln_dockey.
*      ls_cpid-parentdocumenttype = 1.
*      ls_cpid-parentdocumentkey = 1.
      ls_cpid-cat_id = 2."Pedidos
      ls_cpid-isadjustment = abap_true.
      ls_cpid-status = 'C'."Commited
      ls_cpid-createdby = cl_abap_context_info=>get_user_technical_name( ).
      ls_cpid-createdat = ld_tmst.
      APPEND ls_cpid TO lt_cpid.
      MOVE-CORRESPONDING ls_cpid TO ls_cpd.
      APPEND ls_cpd TO lt_cpd.
*      MOVE-CORRESPONDING ls_cpid TO ls_cpdf.
*      ls_cpdf-tstmpl = ld_tmst.
*      ls_cpdf-type = 'S'."Success
*      ls_cpdf-message = 'Documento PurchaseOrder dummy satisfactorio'.
*      APPEND ls_cpdf TO lt_cpdf.
      MOVE-CORRESPONDING ls_cpid TO ls_cpdl.
      APPEND ls_cpdl TO lt_cpdl.

      "SupplierInvoice
      CLEAR: ls_cpid.
      ln_parentdockey = ln_dockey.
      ln_dockey = ln_dockey + 1.
      MOVE-CORRESPONDING <ls_cpic> TO ls_cpid.
      ls_cpid-documenttype = 50."SupplierInvoice
      ls_cpid-documentkey = ln_dockey.
      ls_cpid-parentdocumenttype = 20."PurchaseOrder
      ls_cpid-parentdocumentkey = ln_parentdockey..
      ls_cpid-cat_id = 3."Factura
      ls_cpid-isadjustment = abap_true.
      ls_cpid-status = 'E'."Error
      ls_cpid-createdby = cl_abap_context_info=>get_user_technical_name( ).
      ls_cpid-createdat = ld_tmst.
      APPEND ls_cpid TO lt_cpid.
      MOVE-CORRESPONDING ls_cpid TO ls_cpd.
      APPEND ls_cpd TO lt_cpd.
*      MOVE-CORRESPONDING ls_cpid TO ls_cpdf.
*      ls_cpdf-tstmpl = ld_tmst.
*      ls_cpdf-type = 'E'."Error
*      ls_cpdf-message = 'Documento SupplierInvoice dummy erroneo'.
*      APPEND ls_cpdf TO lt_cpdf.
      MOVE-CORRESPONDING ls_cpid TO ls_cpdl.
      APPEND ls_cpdl TO lt_cpdl.

      "SupplierInvoice
      CLEAR: ls_cpid.
*      ln_parentdockey = ln_dockey.
      ln_dockey = ln_dockey + 1.
      MOVE-CORRESPONDING <ls_cpic> TO ls_cpid.
      ls_cpid-documenttype = 50."SupplierInvoice
      ls_cpid-documentkey = ln_dockey.
      ls_cpid-parentdocumenttype = 20."PurchaseOrder
      ls_cpid-parentdocumentkey = ln_parentdockey..
      ls_cpid-cat_id = 3."Factura
      ls_cpid-isadjustment = abap_true.
      ls_cpid-status = 'C'."Commited
      ls_cpid-createdby = cl_abap_context_info=>get_user_technical_name( ).
      ls_cpid-createdat = ld_tmst.
      APPEND ls_cpid TO lt_cpid.
      MOVE-CORRESPONDING ls_cpid TO ls_cpd.
      APPEND ls_cpd TO lt_cpd.
*      MOVE-CORRESPONDING ls_cpid TO ls_cpdf.
*      ls_cpdf-tstmpl = ld_tmst.
*      ls_cpdf-type = 'S'."Success
*      ls_cpdf-message = 'Documento SupplierInvoice dummy satisfactorio'.
*      APPEND ls_cpdf TO lt_cpdf.
      MOVE-CORRESPONDING ls_cpid TO ls_cpdl.
      APPEND ls_cpdl TO lt_cpdl.
    ENDLOOP.

    MODIFY zfi_a_intrc_cpd FROM TABLE @lt_cpd.
    MODIFY zfi_a_intrc_cpdl FROM TABLE @lt_cpdl.
    MODIFY zfi_a_intrc_cpid FROM TABLE @lt_cpid.
*    MODIFY zfi_a_intrc_cpdf FROM TABLE @lt_cpdf.
    COMMIT WORK.

    rv_len = lines( lt_cpic ).
  ENDMETHOD.

  METHOD if_oo_adt_classrun~main.
    DATA: lt_cpid      TYPE STANDARD TABLE OF zfi_a_intrc_cpid.

*    APPEND VALUE #( itemcalc_id = 1 commitstatus = 'S' markup = 1 grossingupbase = 1 grossingupmargin = 1 ) TO lt_cpic.

    zcl_interco_cpid_data_load=>clean_table(  ).
    DATA(lv_len) = zcl_interco_cpid_data_load=>load_data( lt_cpid ).
    out->write( |Total de registros carregados na zfi_a_intrc_cpid { sy-sysid }.{ sy-mandt }: { 0 }.| ).

  ENDMETHOD.

ENDCLASS.
