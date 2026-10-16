CLASS lcl_abap_behv_event_handler DEFINITION INHERITING FROM cl_abap_behavior_event_handler.

  PRIVATE SECTION.
    TYPES: gtty_proposal            TYPE STANDARD TABLE OF zfi_a_intrc_cph WITH DEFAULT KEY,
           gtty_proposal_upd        TYPE TABLE FOR UPDATE zi_intercoproposal,
           gtty_proposal_item       TYPE STANDARD TABLE OF zfi_a_intrc_cpi WITH DEFAULT KEY,
           gtty_proposal_item_basis TYPE STANDARD TABLE OF zfi_a_intrc_cpib WITH DEFAULT KEY,
           gtty_proposal_item_calc  TYPE STANDARD TABLE OF zfi_a_intrc_cpic WITH DEFAULT KEY,
           gtty_proposal_document   TYPE STANDARD TABLE OF zfi_a_intrc_cpid  WITH DEFAULT KEY.
    TYPES:
      BEGIN OF ty_document_type ,
        type TYPE zfi_a_intrc_cpid-documenttype,
      END OF ty_document_type .
    METHODS consume_commit_event FOR ENTITY EVENT keys FOR zi_intercoproposal~commited.
    METHODS consume_test_event FOR ENTITY EVENT keys FOR zi_intercoproposal~testing.
    METHODS reverse_event            FOR ENTITY EVENT keys FOR zi_intercoproposal~reversed.
    METHODS consume_finished_event FOR ENTITY EVENT keys FOR zi_intercoproposal~finished.
    METHODS consume_simulation_event FOR ENTITY EVENT keys FOR zi_intercoproposal~simulated.

    METHODS prepareproposaltoupd
      IMPORTING it_proposal        TYPE gtty_proposal
                iv_proposal_status TYPE zint_dte_cph_status
      RETURNING VALUE(rt_proposal) TYPE gtty_proposal_upd.

    METHODS processinterdivscenario
      IMPORTING it_proposal                  TYPE gtty_proposal
                it_proposal_item             TYPE gtty_proposal_item
                it_proposal_item_basis       TYPE gtty_proposal_item_basis
                it_proposal_item_calc        TYPE gtty_proposal_item_calc
      RETURNING VALUE(rt_proposal_documents) TYPE gtty_proposal_document.

    METHODS processsoandposcenario
      IMPORTING it_proposal                  TYPE gtty_proposal
                it_proposal_item             TYPE gtty_proposal_item
                it_proposal_item_basis       TYPE gtty_proposal_item_basis
                it_proposal_item_calc        TYPE gtty_proposal_item_calc
      RETURNING VALUE(rt_proposal_documents) TYPE gtty_proposal_document.

    METHODS processbillingscenario
      IMPORTING it_proposal                  TYPE gtty_proposal
                it_proposal_item             TYPE gtty_proposal_item
                it_proposal_item_basis       TYPE gtty_proposal_item_basis
                it_proposal_item_calc        TYPE gtty_proposal_item_calc
                it_proposal_documents        TYPE gtty_proposal_document
      RETURNING VALUE(rt_proposal_documents) TYPE gtty_proposal_document.

    METHODS saveproposaldocuments
      IMPORTING it_proposal           TYPE gtty_proposal
                it_proposal_documents TYPE gtty_proposal_document.

ENDCLASS.



CLASS lcl_abap_behv_event_handler IMPLEMENTATION.

  METHOD consume_commit_event.
    DATA ls_interco_h TYPE zi_intercoproposal.
    DATA lt_interco_i TYPE TABLE OF zi_intercoproposalitem.
    DATA lt_interco_b TYPE TABLE OF zi_intercoproposalitembasis.
    DATA lt_interco_baoglacc TYPE TABLE OF zc_intecoproposalitembaogl2.
    DATA lt_interco_baoglacc_mla TYPE TABLE OF zc_intrcproposalitembaogl2_mla.
    DATA lt_interco_c TYPE TABLE OF zi_intercoproposalitemcalc.
    DATA lt_interco_d TYPE TABLE OF zi_intercoproposalitemdoc.
    DATA lv_debug     TYPE abap_boolean.
    DATA lv_amount    TYPE zi_intercoproposalitembasis-amountinglobalcurrency.

    DATA(ls_keys) = keys[ 1 ].
    "Test to view how many documents with error NOT need to be re-process ( @zcl_proposal_bo_abs=>gc_status_commit, @zcl_proposal_bo_abs=>gc_status_error )
    SELECT * " id, Item_Id,  Itembasis_Id,  Itemcalc_Id,  Documenttype,  documentkey
    FROM zi_intercoproposalitemdoc WHERE id EQ @ls_keys-id
                                     AND status IN ( @zcl_proposal_bo_abs=>c_document_status-commit, @zcl_proposal_bo_abs=>c_document_status-error )
                                     AND isdeleted EQ @abap_false INTO TABLE @lt_interco_d.

    SELECT SINGLE * FROM zi_intercoproposal WHERE id EQ @ls_keys-id INTO @ls_interco_h.

    SELECT DISTINCT _c~* FROM zi_intercoproposalitemcalc AS _c
    LEFT JOIN zi_intercoproposalitemdoc AS _d  ON _d~id             EQ _c~id
                                              AND _d~item_id         EQ _c~item_id
                                              AND _d~itembasis_id    EQ _c~itembasis_id
                                              AND _d~itemcalc_id     EQ _c~itemcalc_id
                                              AND _d~status         IN ( @zcl_proposal_bo_abs=>c_document_status-commit, @zcl_proposal_bo_abs=>c_document_status-error )
    WHERE _c~id EQ @ls_keys-id AND _c~commitstatus EQ @space INTO TABLE @lt_interco_c.

    SELECT DISTINCT _b~* FROM zc_intecoproposalitembaogl2  AS _b
        INNER JOIN zi_intercoproposalitem AS _i ON  _b~id            EQ _i~id
                                                AND _b~item_id       EQ _i~item_id
                                                AND _b~itembasis_id  EQ _i~itembasis_id
        LEFT JOIN zi_intercoproposalitemdoc AS _d  ON _d~id             EQ _i~id
                                                  AND _d~item_id        EQ _i~item_id
                                                  AND _d~itembasis_id   EQ _i~itembasis_id
                                                  AND _d~itemcalc_id    EQ _i~itemcalc_id
                                                  AND _d~status         IN ( @zcl_proposal_bo_abs=>c_document_status-commit, @zcl_proposal_bo_abs=>c_document_status-error )
         WHERE _i~id EQ @ls_keys-id
*         AND _b~amountinglobalcurrency NE @lv_amount"lv_amount has initial value 0.00
         INTO TABLE @lt_interco_baoglacc.
*Ini EXT_OSCUGALD 27.05.2026 - Cost Sharing: poblar lt_interco_baoglacc para IC/CS
    " Para IC/CS ZC_INTECOPROPOSALITEMBAOGL2 devuelve vacío porque cpbg.gl_account=space
    " rompe el JOIN con _ItemsOrGLAcct. Se construye lt_interco_baoglacc via JOIN SQL
    " (ATC clean: sin loop anidado, sin SELECT *). Solo ejecuta si la vista devuelve vacío
    " y el producto es Cost Sharing — no afecta otros escenarios.
    IF lt_interco_baoglacc IS INITIAL.
      SELECT SINGLE low FROM zi_tvarvc
        WHERE name = 'ZINTERCO_CS_PRODUCT'
          AND type = 'S'
          AND low  = @ls_interco_h-product
        INTO @DATA(lv_cs_prod_check).
      IF sy-subrc = 0.
        DATA lv_cs_ceco_prefix TYPE c LENGTH 4.
        DATA lv_cs_cebe        TYPE c LENGTH 3.
        SELECT SINGLE low FROM zi_tvarvc
          WHERE name = 'ZINTERCO_CS_CECO_PREFIX' AND type = 'P'
          INTO @lv_cs_ceco_prefix.
        IF sy-subrc <> 0. lv_cs_ceco_prefix = '9590'. ENDIF.
        SELECT SINGLE low FROM zi_tvarvc
          WHERE name = 'ZINTERCO_CS_CEBE' AND type = 'P'
          INTO @lv_cs_cebe.
        IF sy-subrc <> 0. lv_cs_cebe = '999'. ENDIF.
*Ini EXT_OSCUGALD 29.05.2026 - Cost Sharing: internalcodes de receptoras para CeCo del AP
        " El AP postea en la soc. receptora => CeCo usa internalcode de ESA sociedad
        " igual que RECL_GASTO: EBA->9590112999, IFB->9590210999, MPB->9590130999, SOC->9590219999
        SELECT companycode, internalcode
          FROM zi_intercocompanycode
          WHERE sitecode = @ls_interco_h-providercompanycode
          INTO TABLE @DATA(lt_cs_companies_ap).
*Fin EXT_OSCUGALD 29.05.2026 - Cost Sharing

*Ini EXT_OSCUGALD 28.05.2026 - Cost Sharing: fix amountintcurr y reducir filas BAOGL
        SELECT DISTINCT
                    _b~id,
                    _b~item_id,
                    _b~itembasis_id,
                    _i~recipientcompanycode,
                    _b~globalcurrency,
                    _b~amountinglobalcurrency,
                    _b~amountincompanycodecurrency AS amountintcurr,
                    _b~companycodecurrency         AS transactioncurrency,
                    _b~companycodecurrency,
                    _b~amountincompanycodecurrency,
                    _b~exchangerate,
                    _b~sharedrate,
                    _bg~gl_account                 AS glaccount,
                    _g~pandlid                     AS idl3,
                    _b~companycodecurrency         AS costcenter,
                    @ls_interco_h-product          AS product,
                    @ls_interco_h-providercompanycode AS providercompanycode,
                    @ls_interco_h-internalcode     AS internalcode,
                    _cc~country                    AS recipientcountry
                  FROM zfi_a_intrc_cpib AS _b
                  INNER JOIN zfi_a_intrc_cpi AS _i
                    ON _i~id      = _b~id
                   AND _i~item_id = _b~item_id
                  INNER JOIN zfi_a_intrc_cpbg AS _bg
                    ON _bg~id           = _b~id
                   AND _bg~item_id      = _b~item_id
                   AND _bg~itembasis_id = _b~itembasis_id
                  INNER JOIN zi_intercoglacctdetermination AS _g
                    ON _g~product             = @ls_interco_h-product
                   AND _g~providercompanycode = @ls_interco_h-providercompanycode
                   AND _g~glaccount1          = _bg~gl_account
                   AND _g~isdeleted           = ''
                  INNER JOIN zi_intercocompanycode AS _cc
                    ON _cc~companycode = _i~recipientcompanycode
                  WHERE _b~id        = @ls_keys-id
                    AND _g~doctype   = @zcl_interco_doc_glaccount=>co_doc_type-ar
                  INTO CORRESPONDING FIELDS OF TABLE @lt_interco_baoglacc.
*Fin EXT_OSCUGALD 28.05.2026 - Cost Sharing

*Ini EXT_OSCUGALD 29.05.2026 - Cost Sharing: fix campos vacios en lt_baogl para AP
        " base=0  → DO loop en process_baogl_for_company hace CONTINUE → GL items no se crean → RW033
        " CeCo → internalcode de RECEPTORA (KI302 si se usa el del provider)
        " exchangerate → dejar 0 para mismo pais BRL/BRL (F5701 si se pone 1)
        LOOP AT lt_interco_baoglacc ASSIGNING FIELD-SYMBOL(<ls_cs_baogl_fix>).
          " Fix 1: base no-inicial para que el DO loop cree el GL item
          IF <ls_cs_baogl_fix>-base = 0.
            <ls_cs_baogl_fix>-base = 1.
          ENDIF.
          " Fix 2: CeCo con internalcode de la soc. RECEPTORA (AP postea en ella)
          READ TABLE lt_cs_companies_ap INTO DATA(ls_cs_company_ap)
            WITH KEY companycode = <ls_cs_baogl_fix>-recipientcompanycode.
          DATA(lv_ap_internalcode) = COND #(
            WHEN sy-subrc = 0 AND ls_cs_company_ap-internalcode IS NOT INITIAL
            THEN ls_cs_company_ap-internalcode
            ELSE ls_interco_h-internalcode ).
          <ls_cs_baogl_fix>-costcenter =
            |{ lv_cs_ceco_prefix }{ lv_ap_internalcode }{ lv_cs_cebe }|.
        ENDLOOP.
*Fin EXT_OSCUGALD 29.05.2026 - Cost Sharing
      ENDIF.
    ENDIF.
*Fin EXT_OSCUGALD 27.05.2026 - Cost Sharing
*Ini EXT_OSCUGALD 13.02.2026 - MLA Genova
    " Tabla dedicada para MLA
    " 1. Carga de constantes TVARVC (Filtros Genova)
    SELECT name, type, low FROM zi_tvarvc
      WHERE name IN ('Z_GENOVA_PROVIDER', 'Z_GENOVA_PRODUCT', 'Z_GENOVA_HIER')
      INTO TABLE @DATA(lt_constants).

    " 2. Determinación de escenario MLA
    " Validamos si el Provider de la propuesta coincide con la TVARVC
    DATA(lv_is_genova) = abap_false.

    IF line_exists( lt_constants[ name = 'Z_GENOVA_PROVIDER' low = ls_interco_h-providercompanycode ] ) AND
       line_exists( lt_constants[ name = 'Z_GENOVA_PRODUCT'  low = ls_interco_h-product ] ).
      lv_is_genova = abap_true.
    ENDIF.

    IF lv_is_genova = abap_true.
      SELECT DISTINCT _b~* FROM zc_intrcproposalitembaogl2_mla AS _b
          INNER JOIN zi_proposalitem_mla AS _i ON  _b~id            EQ _i~id
                                                  AND _b~item_id       EQ _i~item_id
                                                  AND _b~itembasis_id  EQ _i~itembasis_id
          LEFT JOIN zi_intercoproposalitemdoc AS _d  ON _d~id             EQ _i~id
                                                    AND _d~item_id        EQ _i~item_id
                                                    AND _d~itembasis_id   EQ _i~itembasis_id
                                                    AND _d~itemcalc_id    EQ _i~itemcalc_id
                                                    AND _d~status         IN ( @zcl_proposal_bo_abs=>c_document_status-commit, @zcl_proposal_bo_abs=>c_document_status-error )
           WHERE _i~id EQ @ls_keys-id
             AND _i~baseamountprofitcenter NE 0
           INTO TABLE @lt_interco_baoglacc_mla.
    ENDIF.
*Fin EXT_OSCUGALD 13.02.2026 - MLA Genova

    SELECT DISTINCT _b~* FROM zi_intercoproposalitembasis  AS _b
    INNER JOIN zi_intercoproposalitemcalc AS _c ON _b~id            EQ _c~id
                                               AND _b~item_id       EQ _c~item_id
                                               AND _b~itembasis_id  EQ _c~itembasis_id
    LEFT JOIN zi_intercoproposalitemdoc AS _d  ON _d~id             EQ _c~id
                                              AND _d~item_id         EQ _c~item_id
                                              AND _d~itembasis_id    EQ _c~itembasis_id
                                              AND _d~itemcalc_id     EQ _c~itemcalc_id
                                              AND _d~status         IN ( @zcl_proposal_bo_abs=>c_document_status-commit, @zcl_proposal_bo_abs=>c_document_status-error )
     WHERE _c~id EQ @ls_keys-id
*     AND _b~amountinglobalcurrency NE @lv_amount"lv_amount has initial value 0.00
     INTO TABLE @lt_interco_b.

    SELECT DISTINCT _i~* FROM zi_intercoproposalitem AS _i
    INNER JOIN zi_intercoproposalitembasis  AS _b ON _b~id EQ _i~id
                                               AND _b~item_id EQ _i~item_id
    INNER JOIN zi_intercoproposalitemcalc AS _c ON _b~id EQ _c~id
                                               AND _b~item_id EQ _c~item_id
                                               AND _b~itembasis_id EQ _c~itembasis_id
    LEFT JOIN zi_intercoproposalitemdoc AS _d  ON _d~id             EQ _c~id
                                              AND _d~item_id         EQ _c~item_id
                                              AND _d~itembasis_id    EQ _c~itembasis_id
                                              AND _d~itemcalc_id     EQ _c~itemcalc_id
                                              AND _d~status         IN ( @zcl_proposal_bo_abs=>c_document_status-commit, @zcl_proposal_bo_abs=>c_document_status-error )
     WHERE _c~id EQ @ls_keys-id
*     AND _i~amountintrasactioncurrency NE @lv_amount"lv_amount has initial value 0.00
     INTO TABLE @lt_interco_i.

    IF  lines( lt_interco_c ) GT 0.
      DATA(lo_proposal) = NEW zcl_boproposal_tools( is_header    = ls_interco_h
                                                    it_items     = lt_interco_i[]
                                                    it_bases     = lt_interco_b[]
                                                    it_baogl     = lt_interco_baoglacc[]
                                                    it_baogl_mla = lt_interco_baoglacc_mla[]
                                                    it_calc      = lt_interco_c[]
                                                    it_doc       = lt_interco_d[]
                                                    iv_process   = zcl_boproposal_tools=>gc_create_doc ).
      DATA(l_ref) = NEW cl_abap_parallel( ).
      l_ref->run_inst(
        EXPORTING
          p_in_tab = VALUE #( ( lo_proposal ) )
          p_debug  = lv_debug
*        IMPORTING
*         p_out_tab = DATA(L_out_tab)
      ).
*      LOOP AT l_out_tab ASSIGNING FIELD-SYMBOL(<l_out>) WHERE inst IS NOT INITIAL.
*        l_inst ?= <l_out>-inst.
*        "use result in L_INST->RESULT.
*      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD prepareproposaltoupd.
    rt_proposal[] = CORRESPONDING #( it_proposal[] ).
    LOOP AT rt_proposal ASSIGNING FIELD-SYMBOL(<fs_proposal>).
      <fs_proposal>-status = iv_proposal_status.
      <fs_proposal>-%control-status = '01'.
    ENDLOOP.
  ENDMETHOD.

  METHOD processinterdivscenario.

    DATA(tl_p_item) = VALUE gtty_proposal_item( FOR ls_p_item IN it_proposal_item
                                                WHERE ( interdivisional = abap_true )
                                                (                       ls_p_item ) ).
    IF tl_p_item IS NOT INITIAL.
      DATA(tl_p_item_basis) = VALUE gtty_proposal_item_basis( FOR ls_p_item IN it_proposal_item
                                                              WHERE ( interdivisional = abap_true )
                                                              FOR ls_p_basis IN it_proposal_item_basis
                                                              WHERE ( item_id         = ls_p_item-item_id )
                                                              (                       ls_p_basis ) ).

      DATA(tl_p_item_calc) = VALUE gtty_proposal_item_calc( FOR ls_p_item IN it_proposal_item
                                                            WHERE ( interdivisional = abap_true )
                                                            FOR ls_p_calc IN it_proposal_item_calc
                                                            WHERE ( item_id         = ls_p_item-item_id )
                                                            (                       ls_p_calc ) ).


      "TODO - Instance Interdivisional Concrete Class and Execute
      "Data(lo_api) = ZCL_INTERCO_CP_ABS=>get_instance(  ZCL_INTERCO_CP_ABS=10 )
      "rt_proposal_documents = lo_api.execute( ).

    ENDIF.

  ENDMETHOD.

  METHOD processsoandposcenario.
    DATA(tl_p_item) = VALUE gtty_proposal_item( FOR ls_p_item IN it_proposal_item
                                                WHERE ( interdivisional = abap_false )
                                                (                       ls_p_item ) ).
    IF tl_p_item IS NOT INITIAL.
      DATA(tl_p_item_basis) = VALUE gtty_proposal_item_basis( FOR ls_p_item IN it_proposal_item
                                                              WHERE ( interdivisional = abap_false )
                                                              FOR ls_p_basis IN it_proposal_item_basis
                                                              WHERE ( item_id         = ls_p_item-item_id )
                                                              (                       ls_p_basis ) ).

      DATA(tl_p_item_calc) = VALUE gtty_proposal_item_calc( FOR ls_p_item IN it_proposal_item
                                                            WHERE ( interdivisional = abap_false )
                                                            FOR ls_p_calc IN it_proposal_item_calc
                                                            WHERE ( item_id         = ls_p_item-item_id )
                                                            (                       ls_p_calc ) ).


      "TODO - Instance SO Concrete Class and Execute
      "Data(lo_api) = ZCL_INTERCO_CP_ABS=>get_instance(  ZCL_INTERCO_CP_ABS= 20 )
      "Data(lt_so_documents) = lo_api.execute( ).

      "TODO - Instance PO Concrete Class and Execute
      "Data(lo_api) = ZCL_INTERCO_CP_ABS=>get_instance(  ZCL_INTERCO_CP_ABS= 50 )
      "Data(lt_po_documents) = lo_api.execute( ).

    ENDIF.
  ENDMETHOD.

  METHOD processbillingscenario.

    "TODO - Instance SO Concrete Class and Execute
    "Data(lo_api) = ZCL_INTERCO_CP_ABS=>get_instance(  ZCL_INTERCO_CP_ABS= 30 )
    "Data(lt_so_documents) = lo_api.execute( ).

    "TODO - Instance SO Concrete Class and Execute
    "Data(lo_api) = ZCL_INTERCO_CP_ABS=>get_instance(  ZCL_INTERCO_CP_ABS= 50 )
    "Data(lt_so_documents) = lo_api.execute( ).


  ENDMETHOD.

  METHOD saveproposaldocuments.

  ENDMETHOD.
  METHOD consume_test_event.

    DATA:
      ls_interco_h TYPE zi_intercoproposal,
      lt_interco_i TYPE TABLE OF zi_intercoproposalitem,
      lt_interco_b TYPE TABLE OF zi_intercoproposalitembasis,
      lt_interco_c TYPE TABLE OF zi_intercoproposalitemcalc,
      lt_interco_d TYPE TABLE OF zi_intercoproposalitemdoc,
      lv_debug     TYPE abap_boolean.

    DATA(ls_keys) = keys[ 1 ].
    "Test to view how many documents with error NOT need to be re-process ( @zcl_proposal_bo_abs=>gc_status_commit, @zcl_proposal_bo_abs=>gc_status_anulated )
    SELECT * "DISTINCT id, Item_Id,  Itembasis_Id,  Itemcalc_Id,  Documenttype,  documentkey
    FROM zi_intercoproposalitemdoc WHERE id EQ @ls_keys-id
                                     AND status IN ( @zcl_proposal_bo_abs=>c_document_status-commit, @zcl_proposal_bo_abs=>c_document_status-error )
                                     AND isdeleted EQ @abap_false INTO TABLE @lt_interco_d.

    SELECT SINGLE * FROM zi_intercoproposal WHERE id EQ @ls_keys-id INTO @ls_interco_h.

    SELECT DISTINCT _c~* FROM zi_intercoproposalitemcalc AS _c
    LEFT JOIN zi_intercoproposalitemdoc AS _d  ON _d~id             EQ _c~id
                                              AND _d~item_id         EQ _c~item_id
                                              AND _d~itembasis_id    EQ _c~itembasis_id
                                              AND _d~itemcalc_id     EQ _c~itemcalc_id
                                              AND _d~status         IN ( @zcl_proposal_bo_abs=>c_document_status-commit, @zcl_proposal_bo_abs=>c_document_status-error )
    WHERE _c~id EQ @ls_keys-id AND _c~commitstatus EQ @space INTO TABLE @lt_interco_c.

    SELECT DISTINCT _b~* FROM zi_intercoproposalitembasis  AS _b
    INNER JOIN zi_intercoproposalitemcalc AS _c ON _b~id            EQ _c~id
                                               AND _b~item_id       EQ _c~item_id
                                               AND _b~itembasis_id  EQ _c~itembasis_id
    LEFT JOIN zi_intercoproposalitemdoc AS _d  ON _d~id             EQ _c~id
                                              AND _d~item_id         EQ _c~item_id
                                              AND _d~itembasis_id    EQ _c~itembasis_id
                                              AND _d~itemcalc_id     EQ _c~itemcalc_id
                                              AND _d~status         IN ( @zcl_proposal_bo_abs=>c_document_status-commit, @zcl_proposal_bo_abs=>c_document_status-error )
     WHERE _c~id EQ @ls_keys-id
     INTO TABLE @lt_interco_b.

    SELECT DISTINCT _i~* FROM zi_intercoproposalitem AS _i
    INNER JOIN zi_intercoproposalitembasis  AS _b ON _b~id EQ _i~id
                                               AND _b~item_id EQ _i~item_id
    INNER JOIN zi_intercoproposalitemcalc AS _c ON _b~id EQ _c~id
                                               AND _b~item_id EQ _c~item_id
                                               AND _b~itembasis_id EQ _c~itembasis_id
    LEFT JOIN zi_intercoproposalitemdoc AS _d  ON _d~id             EQ _c~id
                                              AND _d~item_id         EQ _c~item_id
                                              AND _d~itembasis_id    EQ _c~itembasis_id
                                              AND _d~itemcalc_id     EQ _c~itemcalc_id
                                              AND _d~status         IN ( @zcl_proposal_bo_abs=>c_document_status-commit, @zcl_proposal_bo_abs=>c_document_status-error )
     WHERE _c~id EQ @ls_keys-id
     INTO TABLE @lt_interco_i.

    IF  lines( lt_interco_c ) GT 0.
      DATA(lo_proposal) = NEW zcl_boproposal_tools( is_header  = ls_interco_h
                                                    it_items   = lt_interco_i[]
                                                    it_bases   = lt_interco_b[]
                                                    it_calc    = lt_interco_c[]
                                                    it_doc     = lt_interco_d[]
                                                    iv_process = zcl_boproposal_tools=>gc_create_doc ).
*      lo_proposal->preparedata( ).
      DATA(l_ref) = NEW cl_abap_parallel( ).
      l_ref->run_inst(
        EXPORTING
          p_in_tab = VALUE #( ( lo_proposal ) )
          p_debug  = lv_debug
*        IMPORTING
*         p_out_tab = DATA(L_out_tab)
      ).
*      LOOP AT l_out_tab ASSIGNING FIELD-SYMBOL(<l_out>) WHERE inst IS NOT INITIAL.
*        l_inst ?= <l_out>-inst.
*        "use result in L_INST->RESULT.
*      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD reverse_event.
    DATA:
      ls_interco_h TYPE zi_intercoproposal,
      lt_interco_d TYPE TABLE OF zi_intercoproposalitemdoc,
      lt_interco_i TYPE TABLE OF zi_intercoproposalitem,
      lv_debug     TYPE abap_boolean.

    DATA(ls_keys) = keys[ 1 ].

    SELECT * FROM zi_intercoproposalitemdoc
      WHERE id        EQ @ls_keys-id
        AND status    IN ( @zcl_proposal_bo_abs=>c_document_status-commit )
        AND isdeleted EQ @abap_false
      INTO TABLE @lt_interco_d.
    " CHECK eliminado: si no hay docs, el parallel igual ejecuta set_annulated

    SELECT SINGLE * FROM zi_intercoproposal WHERE id EQ @ls_keys-id INTO @ls_interco_h.

    SELECT DISTINCT _i~* FROM zi_intercoproposalitem AS _i
      WHERE _i~id EQ @ls_keys-id
      INTO TABLE @lt_interco_i.

    DATA(lo_proposal) = NEW zcl_boproposal_tools( is_header  = ls_interco_h
                                                  it_items   = lt_interco_i
                                                  it_doc     = lt_interco_d[]
                                                  iv_process = zcl_boproposal_tools=>gc_reverse_doc ).

    DATA(l_ref) = NEW cl_abap_parallel( ).
    l_ref->run_inst(
      EXPORTING
        p_in_tab = VALUE #( ( lo_proposal ) )
        p_debug  = lv_debug
    ).
***    DATA:
***      ls_interco_h TYPE zi_intercoproposal,
***      lt_interco_d TYPE TABLE OF zi_intercoproposalitemdoc,
***      lt_interco_i TYPE TABLE OF zi_intercoproposalitem,
***      lv_debug     TYPE abap_boolean.
***
***
***    DATA(ls_keys) = keys[ 1 ].
***
***    "Test to view how many documents need to be anulated or re-process anulation ( @zcl_proposal_bo_abs=>gc_status_commit, @zcl_proposal_bo_abs=>gc_status_error_anulated )
***    SELECT * FROM zi_intercoproposalitemdoc
***    WHERE id EQ @ls_keys-id
***    AND status IN ( @zcl_proposal_bo_abs=>c_document_status-commit )", @zcl_proposal_bo_abs=>c_document_status-error )
***    AND isdeleted EQ @abap_false
***    INTO TABLE @lt_interco_d.
***    CHECK sy-subrc EQ 0.
***
***    SELECT DISTINCT _i~* FROM zi_intercoproposalitem AS _i
***     WHERE _i~id EQ @ls_keys-id
***     INTO TABLE @lt_interco_i.
***
***    SELECT SINGLE * FROM zi_intercoproposal WHERE id EQ @ls_keys-id INTO @ls_interco_h.
***    DATA(lo_proposal) = NEW zcl_boproposal_tools( is_header  = ls_interco_h
***                                                  it_items   = lt_interco_i
***                                                  it_doc     = lt_interco_d[]
***                                                  iv_process = zcl_boproposal_tools=>gc_reverse_doc ).
***
***    DATA(l_ref) = NEW cl_abap_parallel( ).
***    l_ref->run_inst(
***      EXPORTING
***        p_in_tab = VALUE #( ( lo_proposal ) )
***        p_debug  = lv_debug
****        IMPORTING
****       p_out_tab = DATA(L_out_tab)
***    ).
****      LOOP AT l_out_tab ASSIGNING FIELD-SYMBOL(<l_out>) WHERE inst IS NOT INITIAL.
****        l_inst ?= <l_out>-inst.
****        "use result in L_INST->RESULT.
****      ENDLOOP.
  ENDMETHOD.
  METHOD consume_finished_event.

    DATA lv_debug     TYPE abap_boolean.
    DATA(l_ref) = NEW cl_abap_parallel( ).
    l_ref->run_inst(
      EXPORTING
        p_in_tab = VALUE #( ( NEW zcl_interco_papm( VALUE #( FOR i_key IN keys ( i_key-id ) ) ) ) )
        p_debug  = lv_debug
*        IMPORTING
*       p_out_tab = DATA(L_out_tab)
    ).

  ENDMETHOD.

  METHOD consume_simulation_event.

    DATA ls_interco_h TYPE zi_intercoproposal.
    DATA lt_interco_i TYPE TABLE OF zi_intercoproposalitem.
    DATA lt_interco_b TYPE TABLE OF zi_intercoproposalitembasis.
    DATA lt_interco_baoglacc TYPE TABLE OF zc_intecoproposalitembaogl2.
    DATA lt_interco_baoglacc_mla TYPE TABLE OF zc_intrcproposalitembaogl2_mla.
    DATA lt_interco_c TYPE TABLE OF zi_intercoproposalitemcalc.
    DATA lt_interco_d TYPE TABLE OF zi_intercoproposalitemdoc.
    DATA lv_debug     TYPE abap_boolean.
    DATA lv_amount    TYPE zi_intercoproposalitembasis-amountinglobalcurrency.

    DATA(ls_keys) = keys[ 1 ].
    "Test to view how many documents with error NOT need to be re-process ( @zcl_proposal_bo_abs=>gc_status_commit, @zcl_proposal_bo_abs=>gc_status_error )
    SELECT * " id, Item_Id,  Itembasis_Id,  Itemcalc_Id,  Documenttype,  documentkey
    FROM zi_intercoproposalitemdoc WHERE id EQ @ls_keys-id
                                     AND status IN ( @zcl_proposal_bo_abs=>c_document_status-commit, @zcl_proposal_bo_abs=>c_document_status-error )
                                     AND isdeleted EQ @abap_false INTO TABLE @lt_interco_d.

    SELECT SINGLE * FROM zi_intercoproposal WHERE id EQ @ls_keys-id INTO @ls_interco_h.

    SELECT DISTINCT _c~* FROM zi_intercoproposalitemcalc AS _c
    LEFT JOIN zi_intercoproposalitemdoc AS _d  ON _d~id             EQ _c~id
                                              AND _d~item_id         EQ _c~item_id
                                              AND _d~itembasis_id    EQ _c~itembasis_id
                                              AND _d~itemcalc_id     EQ _c~itemcalc_id
                                              AND _d~status         IN ( @zcl_proposal_bo_abs=>c_document_status-commit, @zcl_proposal_bo_abs=>c_document_status-error )
    WHERE _c~id EQ @ls_keys-id AND _c~commitstatus EQ @space INTO TABLE @lt_interco_c.

    SELECT DISTINCT _b~* FROM zc_intecoproposalitembaogl2  AS _b
        INNER JOIN zi_intercoproposalitem AS _i ON  _b~id            EQ _i~id
                                                AND _b~item_id       EQ _i~item_id
                                                AND _b~itembasis_id  EQ _i~itembasis_id
        LEFT JOIN zi_intercoproposalitemdoc AS _d  ON _d~id             EQ _i~id
                                                  AND _d~item_id        EQ _i~item_id
                                                  AND _d~itembasis_id   EQ _i~itembasis_id
                                                  AND _d~itemcalc_id    EQ _i~itemcalc_id
                                                  AND _d~status         IN ( @zcl_proposal_bo_abs=>c_document_status-commit, @zcl_proposal_bo_abs=>c_document_status-error )
         WHERE _i~id EQ @ls_keys-id
*         AND _b~amountinglobalcurrency NE @lv_amount"lv_amount has initial value 0.00
         INTO TABLE @lt_interco_baoglacc.
*Ini EXT_OSCUGALD 27.05.2026 - Cost Sharing: poblar lt_interco_baoglacc para IC/CS
    " Para IC/CS ZC_INTECOPROPOSALITEMBAOGL2 devuelve vacío porque cpbg.gl_account=space
    " rompe el JOIN con _ItemsOrGLAcct. Se construye lt_interco_baoglacc via JOIN SQL
    " (ATC clean: sin loop anidado, sin SELECT *). Solo ejecuta si la vista devuelve vacío
    " y el producto es Cost Sharing — no afecta otros escenarios.
    IF lt_interco_baoglacc IS INITIAL.
      SELECT SINGLE low FROM zi_tvarvc
        WHERE name = 'ZINTERCO_CS_PRODUCT'
          AND type = 'S'
          AND low  = @ls_interco_h-product
        INTO @DATA(lv_cs_prod_check).
      IF sy-subrc = 0.
        DATA lv_cs_ceco_prefix TYPE c LENGTH 4.
        DATA lv_cs_cebe        TYPE c LENGTH 3.
        SELECT SINGLE low FROM zi_tvarvc
          WHERE name = 'ZINTERCO_CS_CECO_PREFIX' AND type = 'P'
          INTO @lv_cs_ceco_prefix.
        IF sy-subrc <> 0. lv_cs_ceco_prefix = '9590'. ENDIF.
        SELECT SINGLE low FROM zi_tvarvc
          WHERE name = 'ZINTERCO_CS_CEBE' AND type = 'P'
          INTO @lv_cs_cebe.
        IF sy-subrc <> 0. lv_cs_cebe = '999'. ENDIF.
*Ini EXT_OSCUGALD 29.05.2026 - Cost Sharing: internalcodes de receptoras para CeCo del AP
        " El AP postea en la soc. receptora => CeCo usa internalcode de ESA sociedad
        " igual que RECL_GASTO: EBA->9590112999, IFB->9590210999, MPB->9590130999, SOC->9590219999
        SELECT companycode, internalcode
          FROM zi_intercocompanycode
          WHERE sitecode = @ls_interco_h-providercompanycode
          INTO TABLE @DATA(lt_cs_companies_ap).
*Fin EXT_OSCUGALD 29.05.2026 - Cost Sharing

*Ini EXT_OSCUGALD 28.05.2026 - Cost Sharing: fix amountintcurr y reducir filas BAOGL
        SELECT DISTINCT
                    _b~id,
                    _b~item_id,
                    _b~itembasis_id,
                    _i~recipientcompanycode,
                    _b~globalcurrency,
                    _b~amountinglobalcurrency,
                    _b~amountincompanycodecurrency AS amountintcurr,
                    _b~companycodecurrency         AS transactioncurrency,
                    _b~companycodecurrency,
                    _b~amountincompanycodecurrency,
                    _b~exchangerate,
                    _b~sharedrate,
                    _bg~gl_account                 AS glaccount,
                    _g~pandlid                     AS idl3,
                    _b~companycodecurrency         AS costcenter,
                    @ls_interco_h-product          AS product,
                    @ls_interco_h-providercompanycode AS providercompanycode,
                    @ls_interco_h-internalcode     AS internalcode,
                    _cc~country                    AS recipientcountry
                  FROM zfi_a_intrc_cpib AS _b
                  INNER JOIN zfi_a_intrc_cpi AS _i
                    ON _i~id      = _b~id
                   AND _i~item_id = _b~item_id
                  INNER JOIN zfi_a_intrc_cpbg AS _bg
                    ON _bg~id           = _b~id
                   AND _bg~item_id      = _b~item_id
                   AND _bg~itembasis_id = _b~itembasis_id
                  INNER JOIN zi_intercoglacctdetermination AS _g
                    ON _g~product             = @ls_interco_h-product
                   AND _g~providercompanycode = @ls_interco_h-providercompanycode
                   AND _g~glaccount1          = _bg~gl_account
                   AND _g~isdeleted           = ''
                  INNER JOIN zi_intercocompanycode AS _cc
                    ON _cc~companycode = _i~recipientcompanycode
                  WHERE _b~id        = @ls_keys-id
                    AND _g~doctype   = @zcl_interco_doc_glaccount=>co_doc_type-ar
                  INTO CORRESPONDING FIELDS OF TABLE @lt_interco_baoglacc.
*Fin EXT_OSCUGALD 28.05.2026 - Cost Sharing

*Ini EXT_OSCUGALD 29.05.2026 - Cost Sharing: fix campos vacios en lt_baogl para AP
        " base=0  → DO loop en process_baogl_for_company hace CONTINUE → GL items no se crean → RW033
        " CeCo → internalcode de RECEPTORA (KI302 si se usa el del provider)
        " exchangerate → dejar 0 para mismo pais BRL/BRL (F5701 si se pone 1)
        LOOP AT lt_interco_baoglacc ASSIGNING FIELD-SYMBOL(<ls_cs_baogl_fix>).
          " Fix 1: base no-inicial para que el DO loop cree el GL item
          IF <ls_cs_baogl_fix>-base = 0.
            <ls_cs_baogl_fix>-base = 1.
          ENDIF.
          " Fix 2: CeCo con internalcode de la soc. RECEPTORA (AP postea en ella)
          READ TABLE lt_cs_companies_ap INTO DATA(ls_cs_company_ap)
            WITH KEY companycode = <ls_cs_baogl_fix>-recipientcompanycode.
          DATA(lv_ap_internalcode) = COND #(
            WHEN sy-subrc = 0 AND ls_cs_company_ap-internalcode IS NOT INITIAL
            THEN ls_cs_company_ap-internalcode
            ELSE ls_interco_h-internalcode ).
          <ls_cs_baogl_fix>-costcenter =
            |{ lv_cs_ceco_prefix }{ lv_ap_internalcode }{ lv_cs_cebe }|.
        ENDLOOP.
*Fin EXT_OSCUGALD 29.05.2026 - Cost Sharing
      ENDIF.
    ENDIF.
*Fin EXT_OSCUGALD 27.05.2026 - Cost Sharing
*Ini EXT_OSCUGALD 13.02.2026 - MLA Genova
    " Tabla dedicada para MLA
    " 1. Carga de constantes TVARVC (Filtros Genova)
    SELECT name, type, low FROM zi_tvarvc
      WHERE name IN ('Z_GENOVA_PROVIDER', 'Z_GENOVA_PRODUCT', 'Z_GENOVA_HIER')
      INTO TABLE @DATA(lt_constants).

    " 2. Determinación de escenario MLA
    " Validamos si el Provider de la propuesta coincide con la TVARVC
    DATA(lv_is_genova) = abap_false.

    IF line_exists( lt_constants[ name = 'Z_GENOVA_PROVIDER' low = ls_interco_h-providercompanycode ] ) AND
       line_exists( lt_constants[ name = 'Z_GENOVA_PRODUCT'  low = ls_interco_h-product ] ).
      lv_is_genova = abap_true.
    ENDIF.

    IF lv_is_genova = abap_true.
      " Tabla dedicada para MLA
      SELECT DISTINCT _b~* FROM zc_intrcproposalitembaogl2_mla AS _b
          INNER JOIN zi_proposalitem_mla AS _i ON  _b~id            EQ _i~id
                                                  AND _b~item_id       EQ _i~item_id
                                                  AND _b~itembasis_id  EQ _i~itembasis_id
          LEFT JOIN zi_intercoproposalitemdoc AS _d  ON _d~id             EQ _i~id
                                                    AND _d~item_id        EQ _i~item_id
                                                    AND _d~itembasis_id   EQ _i~itembasis_id
                                                    AND _d~itemcalc_id    EQ _i~itemcalc_id
                                                    AND _d~status         IN ( @zcl_proposal_bo_abs=>c_document_status-commit, @zcl_proposal_bo_abs=>c_document_status-error )
           WHERE _i~id EQ @ls_keys-id
           INTO TABLE @lt_interco_baoglacc_mla.
    ENDIF.
*Fin EXT_OSCUGALD 13.02.2026 - MLA Genova
    SELECT DISTINCT _b~* FROM zi_intercoproposalitembasis  AS _b
    INNER JOIN zi_intercoproposalitemcalc AS _c ON _b~id            EQ _c~id
                                               AND _b~item_id       EQ _c~item_id
                                               AND _b~itembasis_id  EQ _c~itembasis_id
    LEFT JOIN zi_intercoproposalitemdoc AS _d  ON _d~id             EQ _c~id
                                              AND _d~item_id         EQ _c~item_id
                                              AND _d~itembasis_id    EQ _c~itembasis_id
                                              AND _d~itemcalc_id     EQ _c~itemcalc_id
                                              AND _d~status         IN ( @zcl_proposal_bo_abs=>c_document_status-commit, @zcl_proposal_bo_abs=>c_document_status-error )
     WHERE _c~id EQ @ls_keys-id
*     AND _b~amountinglobalcurrency NE @lv_amount"lv_amount has initial value 0.00
     INTO TABLE @lt_interco_b.


    SELECT DISTINCT _i~* FROM zi_intercoproposalitem AS _i
     INNER JOIN zi_intercoproposalitembasis  AS _b ON _b~id EQ _i~id
                                                AND _b~item_id EQ _i~item_id
     INNER JOIN zi_intercoproposalitemcalc AS _c ON _b~id EQ _c~id
                                                AND _b~item_id EQ _c~item_id
                                                AND _b~itembasis_id EQ _c~itembasis_id
     LEFT JOIN zi_intercoproposalitemdoc AS _d  ON _d~id             EQ _c~id
                                               AND _d~item_id         EQ _c~item_id
                                               AND _d~itembasis_id    EQ _c~itembasis_id
                                               AND _d~itemcalc_id     EQ _c~itemcalc_id
                                               AND _d~status         IN ( @zcl_proposal_bo_abs=>c_document_status-commit, @zcl_proposal_bo_abs=>c_document_status-error )
      WHERE _c~id EQ @ls_keys-id
      INTO TABLE @lt_interco_i.

    IF  lines( lt_interco_c ) GT 0.
      DATA(lo_proposal) = NEW zcl_boproposal_tools( is_header    = ls_interco_h
                                                    it_items     = lt_interco_i[]
                                                    it_bases     = lt_interco_b[]
                                                    it_baogl     = lt_interco_baoglacc[]
                                                    it_baogl_mla = lt_interco_baoglacc_mla[]
                                                    it_calc      = lt_interco_c[]
                                                    it_doc       = lt_interco_d[]
                                                    iv_process   = zcl_boproposal_tools=>gc_simulate_doc ).
      DATA(l_ref) = NEW cl_abap_parallel( ).
      l_ref->run_inst(
        EXPORTING
          p_in_tab = VALUE #( ( lo_proposal ) )
          p_debug  = lv_debug
*        IMPORTING
*         p_out_tab = DATA(L_out_tab)
      ).
*      LOOP AT l_out_tab ASSIGNING FIELD-SYMBOL(<l_out>) WHERE inst IS NOT INITIAL.
*        l_inst ?= <l_out>-inst.
*        "use result in L_INST->RESULT.
*      ENDLOOP.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
