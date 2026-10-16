CLASS lsc_zi_intercobasis DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.

CLASS lsc_zi_intercobasis IMPLEMENTATION.

  METHOD save_modified.
    " Disparar el evento asíncrono
    LOOP AT create-zi_intercobasis REFERENCE INTO DATA(header).

*      " Establecer el estado de ejecución.
*      MODIFY ENTITIES OF zi_intercobasis IN LOCAL MODE
*                             ENTITY zi_intercobasis
*                             UPDATE FIELDS ( executionstatus )
*                             WITH VALUE #( ( id = header->id executionstatus = 'IN_PROCESS' ) ).
**      header->%data-ExecutionStatus = 'IN_PROCESS'.

      " La cabecera ya tiene el ID final, ya que estamos en la fase de persistencia (Save).
      DATA(ls_params) = VALUE zcl_interco_bgpf=>ty_input_params(
        companycode  = header->companycode
        fiscalyear   = header->fiscalyear
        fiscalperiod = header->fiscalperiod
        ledger       = header->ledger
        paymenttype  = header->paymenttype
        basis_id     = header->id
        background = header->frombackground
      ).
      DATA(lo_operation) = NEW zcl_interco_bgpf( ls_params ).

      TRY.
          DATA(lo_process_factory) = cl_bgmc_process_factory=>get_default( ).
          DATA(lo_process) = lo_process_factory->create( ).

          lo_process->set_name( 'Interco Basis Creation' )->set_operation_tx_uncontrolled( lo_operation ).
          lo_process->save_for_execution( ).

        CATCH cx_bgmc INTO DATA(lx_bgmc).
          " RAP lanzará un mensaje de error genérico al usuario.
          RAISE EXCEPTION TYPE cx_sy_dyn_call_illegal_class
            EXPORTING
              previous = lx_bgmc.
      ENDTRY.
    ENDLOOP.
    " Agregar un mensaje de éxito al iniciar el proceso
*    APPEND VALUE #(
*              %tky = header->%key
*              %msg = zcl_fi_intrc_messages=>new_message(
*                          textid   = VALUE #( msgid = zcl_fi_intrc_messages=>gc_msgid
*                                              msgno = '213' )
*                          severity = if_abap_behv_message=>severity-success
*                          v1       = header_id
*                      )
*          ) TO reported-zi_intercobasis.

*    DATA(lv_message_text) = |Proceso de creación de base intercompany iniciado en background.|.
*    APPEND VALUE #(
*               %tky = header->%key
*               %msg = new_message_with_text( text     = lv_message_text
*                                             severity = if_abap_behv_message=>severity-success )
*     ) TO reported-zi_intercobasis.

  ENDMETHOD.

ENDCLASS.

CLASS lhc_zi_intercobasis DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zi_intercobasis RESULT result.

    METHODS createbasis FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercobasis~createbasis.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR zi_intercobasis RESULT result.

    METHODS deletebasis FOR MODIFY
      IMPORTING keys   FOR ACTION zi_intercobasis~deletebasis
      RESULT    result.

    METHODS releasebasis FOR MODIFY
      IMPORTING keys   FOR ACTION zi_intercobasis~releasebasis
      RESULT    result.

    METHODS unreleasebasis FOR MODIFY
      IMPORTING keys   FOR ACTION zi_intercobasis~unreleasebasis
      RESULT    result.

    METHODS get_global_features FOR GLOBAL FEATURES
      IMPORTING REQUEST requested_features FOR zi_intercobasis RESULT result.
    METHODS runinbg FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercobasis~runinbg.
    METHODS getbgrun FOR READ
      IMPORTING keys FOR FUNCTION zi_intercobasis~getbgrun RESULT result.

    METHODS validate_isreleased
      IMPORTING iv_header    TYPE zi_intercobasis
      RETURNING VALUE(r_msg) TYPE REF TO if_abap_behv_message.

ENDCLASS.

CLASS lhc_zi_intercobasis IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_instance_features.

    READ ENTITIES OF zi_intercobasis IN LOCAL MODE
         ENTITY zi_intercobasis ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(bases).

*    if sy-sysid = 'PS4'.
*      result = value #( for basis in bases ( %tky                 = basis-%tky
*                                             %action-DeleteBasis  = if_abap_behv=>fc-o-disabled
*                                             %action-ReleaseBasis = if_abap_behv=>fc-o-disabled ) ).
*      return.
*    endif.

    result = VALUE #( FOR basis IN bases
                      LET can_delete  = COND #( WHEN basis-isreleased     = abap_true
                                                THEN if_abap_behv=>fc-o-disabled
                                                ELSE if_abap_behv=>fc-o-enabled )
                          can_release = COND #( WHEN basis-isreleased     = abap_true
                                                THEN if_abap_behv=>fc-o-disabled
                                                ELSE if_abap_behv=>fc-o-enabled )
                      IN (                           %tky                 = basis-%tky
                                                     %action-deletebasis  = can_delete
                                                     %action-releasebasis = can_release ) ).

***    result = VALUE #( FOR basis IN bases
***                          LET is_running    = COND #( WHEN basis-executionstatus = 'IN_PROCESS' THEN abap_true ELSE abap_false ) "
***                              is_released   = basis-isreleased
***
***                              " Control basado en is_released (lógica existente)
***                              can_release   = COND #( WHEN is_released = abap_true THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
***                              can_delete    = COND #( WHEN is_released = abap_true THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
***
***                              " Anulación si el proceso está corriendo
***                              final_feature = COND #( WHEN is_running = abap_true THEN if_abap_behv=>fc-o-disabled ELSE can_release )
***                              final_delete  = COND #( WHEN is_running = abap_true THEN if_abap_behv=>fc-o-disabled ELSE can_delete )
***
***                          IN (                           %tky                 = basis-%tky
***                                                         %action-deletebasis  = final_delete
***                                                         %action-releasebasis = final_feature ) ).
  ENDMETHOD.

*  METHOD createbasis.
*    IF keys IS INITIAL.
*      RETURN.
*    ENDIF.
*
*    DATA basis_headers         TYPE TABLE FOR CREATE zi_intercobasis.
*    DATA basis_items          TYPE TABLE FOR CREATE zi_intercobasis\_items.
*    DATA(key) = REF #( keys[ 1 ] ).
*
*    IF key->%param-description IS INITIAL.
*      failed-zi_intercobasis = VALUE #( ( %cid = key->%cid ) ).
*      reported-zi_intercobasis = VALUE #( ( %msg    = new_message_with_text( text = 'Description is required'(001) )
*                                            %global = if_abap_behv=>mk-on ) ).
*      RETURN.
*    ENDIF.
*
*    SELECT
*      FROM zc_intercojeitemclass( p_companycode =  @key->%param-companycode, p_fiscalperiod = @key->%param-fiscalperiod, p_fiscalyear = @key->%param-fiscalyear, p_ledger = @key->%param-ledger, p_paymenttype = @key->%param-paymenttype  )
*      FIELDS companycode                        AS providercompanycode,
*             glaccount,
*             fiscalyear,
*             fiscalperiod,
*             ledger,
*             pandll5id,
*             costcenterstandardhierarea AS costcenterstdhierarea,
*             ccallocation,
*             ccconsolidation,
*             department,
*             concept                            AS product,
*             paymenttype,
*             costcenter,
*             profitcenter,
*             companycodecurrency,
*             globalcurrency,
*             SUM( amountinglobalcurrency )      AS amountinglobalcurrency,
*             SUM( amountincompanycodecurrency ) AS amountincompanycodecurrency,
*             MIN( creationdatetime ) AS mindatetime,
*             MAX( creationdatetime ) AS maxdatetime
**       WHERE IsBillableFilter = @abap_true  "ext_oscugald 12.11.2025 - evalua variable booleana, si es verdadero indica que isbillable = B. el cálculo del campo esta directamente en la vista de consumo zc_intercojeitemclass
*      WHERE isbillable  = 'B'
**        and GLAccount  in @lr_glaccount[]
*        AND ( isreleased IS INITIAL OR isreleased IS NULL )
*      GROUP BY companycode, glaccount, fiscalyear, fiscalperiod, ledger, pandll5id, costcenterstandardhierarea, ccallocation, ccconsolidation, department, concept, paymenttype, costcenter, profitcenter,
*               companycodecurrency, globalcurrency
*      INTO TABLE @DATA(billable_items).
*
*    IF sy-subrc <> 0.
*      failed-zi_intercobasis = VALUE #( ( %cid = key->%cid ) ).
*      reported-zi_intercobasis = VALUE #( ( %msg    = zcl_fi_intrc_messages=>new_message(
*                                          textid   = zcl_fi_intrc_messages=>basis_no_billable
*                                          severity = if_abap_behv_message=>severity-error )
*                                            %global = if_abap_behv=>mk-on ) ).
*      RETURN.
*    ENDIF.
*
*    " Check if there a Basis
*    SELECT SINGLE id, \_header-description, \_header-createdby FROM zi_intercobasisitem
*    WHERE providercompanycode = @key->%param-companycode
*      AND ledger = @key->%param-ledger
*      AND fiscalyear = @key->%param-fiscalyear
*      AND fiscalperiod = @key->%param-fiscalperiod
*      AND paymenttype = @key->%param-paymenttype
*      AND \_header-isreleased IS INITIAL
*        INTO @DATA(existing_basis).
*
*    IF sy-subrc = 0.
*
*      IF key->%param-overwrite IS INITIAL.
*        failed-zi_intercobasis = VALUE #( ( %cid = key->%cid ) ).
*        reported-zi_intercobasis = VALUE #( ( %msg    = zcl_fi_intrc_messages=>new_message(
*                                            textid   = zcl_fi_intrc_messages=>basis_overwrite
*                                            severity = if_abap_behv_message=>severity-error
*                                            v1       = |{ existing_basis-description } ({ existing_basis-id })|
*                                            v2       = existing_basis-createdby )
*                                              %global = if_abap_behv=>mk-on ) ).
*        RETURN.
*      ENDIF.
*
*      MODIFY ENTITIES OF zi_intercobasis IN LOCAL MODE
*        ENTITY zi_intercobasis
*            DELETE FROM VALUE #( ( id = existing_basis-id ) ).
*    ENDIF.
*
*    FINAL(last_day_of_month) = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ key->%param-fiscalyear }{ key->%param-fiscalperiod+1 }01| ).
*    DATA(is_feature_department_enabled) = zcl_interco=>feature->get( 'DEPARTMENT' )->for( iv_companycode = key->%param-companycode iv_validat = last_day_of_month )-enabled.
*
*    IF is_feature_department_enabled = abap_true AND line_exists( billable_items[ department = '' ] ).
*      failed-zi_intercobasis = VALUE #( ( %cid = key->%cid ) ).
*      reported-zi_intercobasis = VALUE #( ( %msg    = new_message_with_text( text = 'The `Department` column cannot be empty.'(002) )
*                                            %global = if_abap_behv=>mk-on ) ).
*      RETURN.
*    ENDIF.
*
*    basis_headers = VALUE #( ( %cid             = key->%cid
*                               ledger           = key->%param-ledger
*                               companycode      = key->%param-companycode
*                               fiscalyear       = key->%param-fiscalyear
*                               fiscalperiod     = key->%param-fiscalperiod
*                               paymenttype      = key->%param-paymenttype
*                               isreleased       = space
*                               reportexecutedat = key->%param-reportexecutedat
*                               description      = key->%param-description ) ).
*    APPEND VALUE #( %cid_ref = key->%cid
*                    %target  = VALUE #( FOR item IN billable_items
*                                       ( CORRESPONDING #( item ) ) ) ) TO basis_items.
*
*    MODIFY ENTITIES OF zi_intercobasis IN LOCAL MODE
*           ENTITY zi_intercobasis
*           CREATE AUTO FILL CID FIELDS ( isreleased reportexecutedat description companycode fiscalyear fiscalperiod paymenttype ledger )
*           WITH basis_headers
*           CREATE BY \_items AUTO FILL CID
*           FIELDS ( providercompanycode fiscalyear fiscalperiod ledger
*                    pandll5id costcenterstdhierarea ccallocation ccconsolidation glaccount department product costcenter profitcenter paymenttype
*                    companycodecurrency globalcurrency amountinglobalcurrency amountincompanycodecurrency mindatetime maxdatetime )
*           WITH basis_items
*           MAPPED   mapped
*           FAILED   failed
*           REPORTED reported.
*
*
*  ENDMETHOD.

  METHOD createbasis.

    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    DATA basis_headers         TYPE TABLE FOR CREATE zi_intercobasis.
    DATA(key) = REF #( keys[ 1 ] ).

    IF key->%param-description IS INITIAL.
      failed-zi_intercobasis = VALUE #( ( %cid = key->%cid ) ).
      reported-zi_intercobasis = VALUE #( ( %msg    = new_message_with_text( text = 'Description is required'(001) )
                                            %global = if_abap_behv=>mk-on ) ).
      RETURN.
    ENDIF.

    SELECT SINGLE id, \_header-description, \_header-createdby FROM zi_intercobasisitem
       WHERE providercompanycode = @key->%param-companycode
       AND ledger = @key->%param-ledger
       AND fiscalyear = @key->%param-fiscalyear
       AND fiscalperiod = @key->%param-fiscalperiod
       AND paymenttype = @key->%param-paymenttype
       AND \_header-isreleased IS INITIAL
       AND \_header-executionstatus <> 'FAILED'
       INTO @DATA(existing_basis).

    IF sy-subrc = 0.

      IF key->%param-overwrite IS INITIAL.
        failed-zi_intercobasis = VALUE #( ( %cid = key->%cid ) ).
        reported-zi_intercobasis = VALUE #( ( %msg    = zcl_fi_intrc_messages=>new_message(
                                            textid   = zcl_fi_intrc_messages=>basis_overwrite
                                            severity = if_abap_behv_message=>severity-error
                                            v1       = |{ existing_basis-description } ({ existing_basis-id })|
                                            v2       = existing_basis-createdby )
                                              %global = if_abap_behv=>mk-on ) ).
        RETURN.
      ENDIF.

      MODIFY ENTITIES OF zi_intercobasis IN LOCAL MODE
        ENTITY zi_intercobasis
            DELETE FROM VALUE #( ( id = existing_basis-id ) ).
    ENDIF.

    basis_headers = VALUE #( ( %cid             = key->%cid
                               ledger           = key->%param-ledger
                               companycode      = key->%param-companycode
                               fiscalyear       = key->%param-fiscalyear
                               fiscalperiod     = key->%param-fiscalperiod
                               paymenttype      = key->%param-paymenttype
                               isreleased       = space
                               reportexecutedat = key->%param-reportexecutedat
                               description      = key->%param-description
                               frombackground = key->%param-background
                               executionstatus  = 'IN_PROCESS') ).

    MODIFY ENTITIES OF zi_intercobasis IN LOCAL MODE
           ENTITY zi_intercobasis
           CREATE AUTO FILL CID FIELDS ( isreleased reportexecutedat description companycode fiscalyear fiscalperiod paymenttype ledger executionstatus frombackground )
           WITH basis_headers
           MAPPED   mapped
           FAILED   failed
           REPORTED reported.

  ENDMETHOD.

  METHOD validate_isreleased.
    IF iv_header-isreleased IS NOT INITIAL.
      r_msg = NEW zintercocx( severity = if_abap_behv_message=>severity-error
                              textid   = zintercocx=>snapshot_released ).
    ENDIF.
  ENDMETHOD.

  METHOD deletebasis.

    MODIFY ENTITIES OF zi_intercobasis IN LOCAL MODE
        ENTITY zi_intercobasis
        DELETE FROM CORRESPONDING #( keys ).

  ENDMETHOD.

  METHOD releasebasis.
    TYPES: BEGIN OF ty_profit_center,
             providercompanycode         TYPE zi_intercocompanyrelproduct-providercompanycode,
             profitcenter                TYPE zi_intercocompanyrelproduct-profitcenter,
             amountincompanycodecurrency TYPE zi_intercobasisitem-amountincompanycodecurrency,
             companycodecurrency         TYPE zi_intercobasisitem-companycodecurrency,
             amountinglobalcurrency      TYPE zi_intercobasisitem-amountinglobalcurrency,
             globalcurrency              TYPE zi_intercobasisitem-globalcurrency,
           END OF ty_profit_center.
    DATA release_bases TYPE TABLE FOR UPDATE zi_intercobasis.

    DATA(has_error) = abap_false.

    READ ENTITIES OF zi_intercobasis IN LOCAL MODE
    ENTITY zi_intercobasis ALL FIELDS WITH CORRESPONDING #( keys ) RESULT FINAL(basis_headers)
         ENTITY zi_intercobasis BY \_items ALL FIELDS WITH CORRESPONDING #( keys ) RESULT FINAL(basis_items)
         FAILED FINAL(read_failed).

    DATA(current_period) = CONV datum( |{ basis_headers[ 1 ]-fiscalyear }{ basis_headers[ 1 ]-fiscalperiod+1 }01| ).

    " ══ AJUSTE MON/MTO LOCAL CPH+CPI: pre-carga de ZFI_A_INTRC_BI ════════════
    " Se lee una sola vez toda la info de moneda local para evitar
    " accesos a BD dentro del loop (ATC: no nested DB reads).
    DATA lt_bi_totals TYPE STANDARD TABLE OF zfi_a_intrc_bi WITH DEFAULT KEY.
    SELECT id,
           companycodecurrency,
           amountincompanycodecurrency
      FROM zfi_a_intrc_bi
      FOR ALL ENTRIES IN @basis_headers
      WHERE id = @basis_headers-id
      INTO CORRESPONDING FIELDS OF TABLE @lt_bi_totals.

    " Agregar en memoria por id (sumar todos los ítems de la base)
    DATA lt_bi_agg TYPE STANDARD TABLE OF zfi_a_intrc_bi WITH DEFAULT KEY.
    LOOP AT lt_bi_totals INTO DATA(ls_bi_raw).
      READ TABLE lt_bi_agg ASSIGNING FIELD-SYMBOL(<ls_bi_agg>)
        WITH KEY id = ls_bi_raw-id.
      IF sy-subrc = 0.
        <ls_bi_agg>-amountincompanycodecurrency += ls_bi_raw-amountincompanycodecurrency.
      ELSE.
        APPEND VALUE zfi_a_intrc_bi(
          id                          = ls_bi_raw-id
          companycodecurrency         = ls_bi_raw-companycodecurrency
          amountincompanycodecurrency = ls_bi_raw-amountincompanycodecurrency
        ) TO lt_bi_agg.
      ENDIF.
    ENDLOOP.
    " ════════════════════════════════════════════════════════════════════════════

    SELECT basis_items~id AS basisid,
               relations~product,
               relations~recipientcompanycode,
               relations~profitcenter,
               basis_items~costcenter,
               basis_items~glaccount,
               basis_items~department,
               SUM( basis_items~amountinglobalcurrency )      AS amountinglobalcurrency,
               basis_items~globalcurrency,
               SUM( basis_items~amountincompanycodecurrency ) AS amountincompanycodecurrency, "ext_oscugald 12.11.2025 - se agrega el monto en moneda de la compañía
               basis_items~companycodecurrency
        FROM zi_intercocompanyrelproduct AS relations
        INNER JOIN @basis_items AS basis_items ON relations~providercompanycode = basis_items~providercompanycode
          AND relations~product = basis_items~product
          AND relations~profitcenter = basis_items~profitcenter
      WHERE relations~isdeleted IS INITIAL
          AND relations~isblocked IS INITIAL
          AND @current_period BETWEEN relations~validfrom AND relations~validto
          GROUP BY basis_items~id,
                   relations~product,
                   recipientcompanycode,
                   relations~profitcenter,
                   basis_items~costcenter,
                   basis_items~glaccount,
                   basis_items~department,
                   globalcurrency,
                   basis_items~companycodecurrency
          INTO TABLE @DATA(proposal_possible_items_det).

    SELECT details~basisid,
         details~product,
         details~recipientcompanycode,
         details~profitcenter,
         SUM( details~amountinglobalcurrency )      AS amountinglobalcurrency,
         details~globalcurrency,
         SUM( details~amountincompanycodecurrency ) AS amountincompanycodecurrency,
         details~companycodecurrency
        FROM @proposal_possible_items_det AS details
        GROUP BY details~basisid,
                 details~product,
                 details~recipientcompanycode,
                 details~profitcenter,
                 details~globalcurrency,
                 details~companycodecurrency
        INTO TABLE @DATA(proposal_possible_items).

*      " ── NUEVO: pre-cargar datos locales de BI para todos los productos ──────
*      DATA lt_bi_local_all TYPE STANDARD TABLE OF zfi_a_intrc_bi WITH DEFAULT KEY.
*      DATA ls_bi_local_currency TYPE zfi_a_intrc_bi-companycodecurrency.

    DO lines( keys ) TIMES.
      DATA(key) = REF #( keys[ sy-index ] ).
      CLEAR has_error.

      IF NOT line_exists(  proposal_possible_items[ basisid = key->id ] ).
        failed-zi_intercobasis = VALUE #( ( %tky = key->%tky ) ).
        reported-zi_intercobasis = VALUE #( (
                                            %global = if_abap_behv=>mk-on
                                            %msg    = zcl_fi_intrc_messages=>new_message(
                                            textid   = zcl_fi_intrc_messages=>relation_not_exists
                                            v1       = space
                                            v2       = basis_items[ id = key->id ]-product
                                            v3       = basis_items[ id = key->id ]-providercompanycode
                                            severity = if_abap_behv_message=>severity-error )
                                          ) ).
        CONTINUE.
      ENDIF.

      " Verify whether the profit centers in the basis are properly defined in the relations. If any are missing, generate an error message.
      LOOP AT basis_items REFERENCE INTO DATA(basis_item) GROUP BY ( key1 = basis_item->product key2 = basis_item->profitcenter ).
        IF NOT line_exists( proposal_possible_items[  profitcenter = basis_item->profitcenter product = basis_item->product ] ).
          failed-zi_intercobasis = VALUE #( ( %tky = key->%tky ) ).
          reported-zi_intercobasis = VALUE #( (
                                              %global = if_abap_behv=>mk-on
                                              %msg    = zcl_fi_intrc_messages=>new_message(
                                              textid   = zcl_fi_intrc_messages=>profit_center_not_in_relations
                                              v1       = basis_item->profitcenter
                                              v2       = basis_item->providercompanycode
                                              severity = if_abap_behv_message=>severity-error )
                                            ) ).
          has_error = abap_true.
        ENDIF.
      ENDLOOP.

      IF has_error = abap_true.
        CONTINUE.
      ENDIF.

      " Create Proposal
      DATA create_proposals TYPE TABLE FOR CREATE zi_intercoproposal.
      DATA create_proposals_items TYPE TABLE FOR CREATE zi_intercoproposal\_items.
      DATA create_proposals_items_details TYPE TABLE FOR CREATE zi_intercoproposalitem\_proposalitemsdetails.

      LOOP AT basis_items REFERENCE INTO basis_item WHERE id = key->id GROUP BY basis_item->product.

        DATA(basis_header) = REF #( basis_headers[ id = basis_item->id ] ).

        APPEND INITIAL LINE TO create_proposals REFERENCE INTO DATA(create_proposal).
        DATA(cid) = sy-tabix.
        create_proposal->* = CORRESPONDING #( basis_item->* ).
        create_proposal->%cid = cid.
        create_proposal->fiscalperiod = basis_header->fiscalperiod.
        create_proposal->status                 = space.
        create_proposal->intercobasisid = basis_item->id.
        create_proposal->globalcurrency = basis_item->globalcurrency.
        create_proposal->amountinglobalcurrency = REDUCE #( INIT total TYPE zi_intercoproposalitem-amountinglobalcurr
                                                             FOR i IN basis_items
                                                                WHERE ( id = key->id AND product = basis_item->product )
                                                              NEXT total += i-amountinglobalcurrency  ).
        " ══ AJUSTE MON/MTO LOCAL CPH: misma lógica que amountinglobalcurrency
        " suma desde basis_items (ZFI_A_INTRC_BI) filtrando por id + product ══
        DATA lv_cph_local_amount TYPE zint_dte_fis_hsl.
        lv_cph_local_amount = REDUCE zint_dte_fis_hsl(
          INIT lv_sum TYPE zint_dte_fis_hsl
          FOR i IN basis_items
          WHERE ( id = key->id AND product = basis_item->product )
          NEXT lv_sum += i-amountincompanycodecurrency ).
        " ════════════════════════════════════════════════════════════════════

        READ TABLE lt_bi_agg INTO DATA(ls_bi_header)
          WITH KEY id = basis_item->id.
        IF sy-subrc = 0.
          create_proposal->CompanyCodeCurrency         = ls_bi_header-companycodecurrency.
          create_proposal->AmountInCompanyCodeCurrency = lv_cph_local_amount.
        ENDIF.
        " ════════════════════════════════════════════════════════════════════

        " Moneda local para los ítems CPI (misma fuente, mismo registro)
        DATA(lv_cpi_currency) = COND #( WHEN sy-subrc = 0
                                        THEN ls_bi_header-companycodecurrency
                                        ELSE '' ).
        " ════════════════════════════════════════════════════════════════════════

        " Itens por Cebe / Prestaria
        APPEND INITIAL LINE TO create_proposals_items REFERENCE INTO DATA(create_proposal_item).
        create_proposal_item->%cid_ref = cid.
        create_proposal_item->%target = VALUE #(
                                                 FOR item IN proposal_possible_items
                                                 WHERE ( basisid                  = basis_item->id AND
                                                         product                  = basis_item->product )
                                                 LET item_id = lines( create_proposal_item->%target ) + 1
                                                 IN    (
                                                         %cid                     = |{ cid }-{ item_id }|
                                                         item_id                  = item_id
                                                         interdivisional          = COND #( WHEN create_proposal->providercompanycode = item-recipientcompanycode THEN abap_true ELSE abap_false )
                                                         recipientcompanycode     = item-recipientcompanycode
                                                         profitcenter             = item-profitcenter
                                                         baseamountprofitcenter   = item-amountinglobalcurrency
                                                         basecurrencyprofitcenter = item-globalcurrency
                                                         " ══ AJUSTE MON/MTO LOCAL CPI ══════════════════════
                                                         " companycodecurrency: moneda local del proveedor
                                                         " amountincompanycodecurrency: monto local por ítem
                                                         " Ambos vienen de ZFI_A_INTRC_BI via lt_bi_agg.
                                                         companycodecurrency         = lv_cpi_currency
                                                         amountincompanycodecurrency = item-amountincompanycodecurrency
                                                         " ═══════════════════════════════════════════════════
                                               ) ).


        " Apertura de Itens (Cebe / Prestataria) por Cuenta y CeCo
        DO lines( create_proposal_item->%target ) TIMES.

          APPEND INITIAL LINE TO create_proposals_items_details REFERENCE INTO DATA(create_proposal_item_detail).
          DATA(proposal_item) = create_proposal_item->%target[ sy-index ].
          create_proposal_item_detail->%cid_ref = proposal_item-%cid.
          create_proposal_item_detail->%target = VALUE #(
                                                          FOR item_det IN proposal_possible_items_det INDEX INTO idx
                                                          WHERE ( basisid                = basis_item->id AND
                                                                  product                = basis_item->product AND
                                                                  profitcenter           = proposal_item-profitcenter AND
                                                                  recipientcompanycode   = proposal_item-recipientcompanycode )
                                                                (
                                                                  %cid                   = |{ cid }-{ proposal_item-item_id }-{ idx }|
                                                                  costcenter             = item_det-costcenter
                                                                  glaccount              = item_det-glaccount
                                                                  globalcurrency         = item_det-globalcurrency
                                                                  department = item_det-department
                                                                  amountinglobalcurrency = item_det-amountinglobalcurrency
                                                                  percentoftotal         = COND #( WHEN proposal_item-baseamountprofitcenter <> 0 THEN item_det-amountinglobalcurrency / proposal_item-baseamountprofitcenter ELSE 0 )
                                                          ) ).
        ENDDO.

      ENDLOOP.

      MODIFY ENTITIES OF zi_intercoproposal
             ENTITY zi_intercoproposal
*                 CREATE FIELDS ( fiscalperiod fiscalyear providercompanycode product status intercobasisid globalcurrency amountinglobalcurrency )
                 CREATE FIELDS ( fiscalperiod fiscalyear providercompanycode product status intercobasisid globalcurrency amountinglobalcurrency CompanyCodeCurrency AmountInCompanyCodeCurrency )
                    WITH create_proposals
*                 CREATE BY \_items FIELDS ( item_id recipientcompanycode profitcenter interdivisional baseamountprofitcenter basecurrencyprofitcenter )
                 CREATE BY \_items FIELDS ( item_id recipientcompanycode profitcenter interdivisional baseamountprofitcenter basecurrencyprofitcenter companycodecurrency amountincompanycodecurrency )
                    WITH create_proposals_items
           ENTITY zi_intercoproposalitem
            CREATE BY \_proposalitemsdetails FIELDS ( glaccount costcenter department amountinglobalcurrency globalcurrency percentoftotal )
            WITH create_proposals_items_details
             FAILED DATA(failed_proposal).

      IF failed_proposal-zi_intercoproposal IS NOT INITIAL.
        failed-zi_intercobasis = VALUE #( ( %tky = key->%tky ) ).
        reported-zi_intercobasis = VALUE #( %global = if_abap_behv=>mk-on
                                            ( %msg = zcl_fi_intrc_messages=>new_message(
                                            textid   = zcl_fi_intrc_messages=>proposal_create_error
                                            severity = if_abap_behv_message=>severity-error ) ) ).

        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky       = key->%tky
                      isreleased = abap_true ) TO release_bases.
    ENDDO.

    MODIFY ENTITIES OF zi_intercobasis IN LOCAL MODE
        ENTITY zi_intercobasis
            UPDATE FIELDS ( isreleased )
                WITH release_bases
                FAILED DATA(_failed)
                MAPPED mapped
                REPORTED DATA(_reported).

    APPEND LINES OF _failed-zi_intercobasis TO failed-zi_intercobasis.
    APPEND LINES OF _reported-zi_intercobasis TO reported-zi_intercobasis.

  ENDMETHOD.

  METHOD unreleasebasis.

    MODIFY ENTITIES OF zi_intercobasis IN LOCAL MODE
          ENTITY zi_intercobasis
              UPDATE FIELDS ( isreleased )
                  WITH VALUE #( FOR key IN keys ( id = key-id isreleased = abap_false ) )
                  FAILED failed
                  MAPPED mapped
                  REPORTED reported.

  ENDMETHOD.

  METHOD get_global_features.

**    if sy-sysid = 'PS4'.
**      result-%action-CreateBasis = if_abap_behv=>fc-o-disabled.
**    endif.

  ENDMETHOD.



  METHOD runinbg.

    DATA(key) = REF #( keys[ 1 ] ).
    DATA bg_process         TYPE TABLE FOR CREATE zr_intercojeitemclassbgtp.


    SELECT SINGLE id, createdat, createdby, pending FROM zi_intercojeitemclassbg
    WHERE companycode = @key->%param-companycode
    AND fiscalperiod = @key->%param-fiscalperiod
    AND fiscalyear = @key->%param-fiscalyear
    AND ledger = @key->%param-ledger
    AND paymenttype = @key->%param-paymenttype
      INTO @DATA(bgprocess).

    DATA(has_entry) = xsdbool( sy-subrc = 0 ).

    " someone is already processing the same report
    IF bgprocess-pending = abap_true.
      RETURN.
    ENDIF.

    "  No permitir mas de una ejecucion en backgorund
    SELECT COUNT( * )
      FROM zi_intercojeitemclassbg
      WHERE pending = @abap_true
      INTO @DATA(in_processing).

    IF in_processing > 0.
      failed-zi_intercobasis = VALUE #( ( %cid = key->%cid ) ).
      reported-zi_intercobasis = VALUE #(
        ( %msg    = new_message(
                      id       = 'ZFI_INTERCO'
                      number   = '215'
                      severity = if_abap_behv_message=>severity-error )
          %global = if_abap_behv=>mk-on )
      ).
      RETURN.
    ENDIF.

    APPEND INITIAL LINE TO bg_process REFERENCE INTO DATA(bgp).
    bgp->id = bgprocess-id.
    bgp->companycode = key->%param-companycode.
    bgp->fiscalperiod = key->%param-fiscalperiod.
    bgp->fiscalyear = key->%param-fiscalyear.
    bgp->ledger = key->%param-ledger.
    bgp->paymenttype = key->%param-paymenttype.
    bgp->allfilters = key->%param-AllFilters.
    bgp->pending = abap_true.

    IF has_entry = abap_true.
      MODIFY ENTITIES OF zr_intercojeitemclassbgtp
      ENTITY header
         UPDATE FIELDS ( pending allfilters )
          WITH CORRESPONDING #( bg_process ).
    ELSE.
      MODIFY ENTITIES OF zr_intercojeitemclassbgtp
          ENTITY header
             CREATE AUTO FILL CID
             FIELDS ( companycode fiscalyear fiscalperiod ledger paymenttype allfilters pending )
              WITH bg_process
               FAILED DATA(failed_create)
               REPORTED DATA(reported_create).
    ENDIF.

  ENDMETHOD.

  METHOD getbgrun.
    DATA(key) = keys[ 1 ].
    SELECT SINGLE companycode, ledger, fiscalyear, fiscalperiod, paymenttype, pending, createdat, createdby
      FROM zi_intercojeitemclassbg
      WHERE companycode = @key-%param-companycode
      AND ledger = @key-%param-ledger
      AND fiscalyear = @key-%param-fiscalyear
      AND fiscalperiod = @key-%param-fiscalperiod
      AND paymenttype = @key-%param-paymenttype
      INTO @DATA(bgprocess).

    result = VALUE #( (  %cid = key-%cid %param = CORRESPONDING #( bgprocess ) ) ).
  ENDMETHOD.

ENDCLASS.
