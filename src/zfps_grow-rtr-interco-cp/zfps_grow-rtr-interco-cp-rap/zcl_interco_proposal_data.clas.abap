CLASS zcl_interco_proposal_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES:
      tt_proposal_header           TYPE TABLE OF zi_intercoproposal WITH KEY id,
      tt_proposal_item             TYPE TABLE OF zi_intercoproposalitem WITH KEY id item_id,
      tt_relationship              TYPE TABLE OF zi_intercorelationship WITH KEY providerbusinesspartner recipientbusinesspartner,
      tt_proposal_item_detail      TYPE TABLE OF zi_intercoproposalitemdetail WITH KEY id item_id,
      tt_proposal_item_calc        TYPE TABLE OF zi_intercoproposalitemcalc WITH KEY id item_id,
      tt_proposal_item_calc_detail TYPE TABLE OF zi_intercoproposalitemcalcdet WITH KEY id item_id glaccount costcenter,
      tt_pandl                     TYPE TABLE OF zi_intercopandlhierflattened WITH KEY id,

      BEGIN OF MESH ty_proposal,
        headers            TYPE tt_proposal_header
              ASSOCIATION _items TO items ON id = id,
        items              TYPE tt_proposal_item
          ASSOCIATION _itemsdetails TO items_details ON id = id AND item_id = item_id
          ASSOCIATION _relationship TO relationships ON providercompanycode = providercompanycode AND
                                                        recipientcompanycode = recipientcompanycode,
        items_details      TYPE tt_proposal_item_detail,
        items_calc         TYPE tt_proposal_item_calc
          ASSOCIATION _items_calc_details TO items_calc_details ON id = id AND item_id = item_id,
        items_calc_details TYPE tt_proposal_item_calc_detail,
        relationships      TYPE tt_relationship,
        pandls             TYPE tt_pandl,
      END OF MESH ty_proposal.

    TYPES: BEGIN OF ty_items_details,
             id                          TYPE zi_intercoproposal-id,
             product                     TYPE zi_intercoproposal-product,
             item_id                     TYPE zi_intercoproposalitem-item_id,
             itembasis_id                TYPE zi_intercoproposalitem-itembasis_id,
             itemcalc_id                 TYPE zi_intercoproposalitem-itemcalc_id,
             tarifftype                  TYPE zi_intercoproposalitemcalcdet-tarifftype,
             tariffdescription           TYPE zi_intercoproposalitemcalcdet-tariffdescription,
             tariffrate                  TYPE zi_intercoproposalitemcalcdet-tariffrate,
             glaccount                   TYPE zi_intercoproposalitemcalcdet-glaccount,
             costcenter                  TYPE zi_intercoproposalitemcalcdet-costcenter,
             costcenterd4                TYPE zi_intercoproposalitemcalcdet-costcenterd4,
             department                  TYPE zi_intercoproposalitemcalcdet-department,
             profitcenter                TYPE zi_intercoproposalitem-profitcenter,
             providercompanycode         TYPE zi_intercoproposal-providercompanycode,
             recipientcompanycode        TYPE zi_intercoproposalitem-recipientcompanycode,
             recipientcountry            TYPE zi_intercoproposalitem-recipientcountry,
             profitcentereq              TYPE zi_intercoproposalitem-profitcentereq,
             companycodecurrency         TYPE zi_intercoproposalitem-companycodecurrency,
             globalcurrency              TYPE zi_intercoproposalitem-globalcurrency,
             idl3                        TYPE zi_intercopandlhierflattened-idl3,
             idl2                        TYPE zi_intercopandlhierflattened-idl2,
             amountintransactioncurrency TYPE zi_intercoproposalitemcalcdet-amountincompanycodecurrency,
             transactioncurrency         TYPE zi_intercoproposalitemcalcdet-companycodecurrency,
             amountinglobalcurrency      TYPE zi_intercoproposalitemcalcdet-amountinglobalcurrency,
             amountincompanycodecurrency TYPE zi_intercoproposalitemcalcdet-amountincompanycodecurrency,
             recipientcustomer           TYPE zi_intercorelationship-recipientcustomer,
             recipientvendor             TYPE zi_intercorelationship-recipientvendor,
             exchangerate                TYPE zi_intercoproposalitem-exchangerate,
             interdivisional             TYPE zi_intercoproposalitem-interdivisional,
           END OF ty_items_details.
    TYPES: tt_items_details TYPE TABLE OF ty_items_details WITH DEFAULT KEY.

    TYPES: tt_proposal_items TYPE TABLE OF zi_intercoproposalitem WITH KEY id item_id.

    DATA data TYPE ty_proposal READ-ONLY.

    METHODS:
      constructor
        IMPORTING
          iv_proposal_id TYPE zi_intercoproposal-id.

    METHODS:
      get_all
        RETURNING VALUE(result) TYPE ty_proposal,

      get_for_journalentry
        IMPORTING it_proposal_items TYPE tt_proposal_items
        RETURNING VALUE(result)     TYPE tt_items_details.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA: proposal_id TYPE zi_intercoproposal-id.
ENDCLASS.



CLASS zcl_interco_proposal_data IMPLEMENTATION.


  METHOD constructor.
    proposal_id = iv_proposal_id.
  ENDMETHOD.


  METHOD get_all.

*    SELECT * FROM zi_intercoproposal
*      WHERE id = @proposal_id
*      INTO TABLE @DATA(proposal_headers).
*
*    data-headers = proposal_headers.
*
*    SELECT * FROM zi_intercoproposalitem
*      WHERE id = @proposal_id
*      INTO TABLE @DATA(proposal_items).
*
*    data-items = proposal_items.
*
*    SELECT * FROM zi_intercoproposalitemdetail
*      WHERE id = @proposal_id
*      INTO TABLE @DATA(proposal_item_details).
*
*    data-items_details = proposal_item_details.
*
*    SELECT * FROM zi_intercoproposalitemcalc
*     WHERE id = @proposal_id
*     INTO TABLE @DATA(proposal_items_calc).
*
*    data-items_calc = proposal_items_calc.
*
*    SELECT * FROM zi_intercoproposalitemcalcdet
*    WHERE id = @proposal_id
*    INTO TABLE @DATA(proposal_items_calc_detail).
*
*    data-items_calc_details = proposal_items_calc_detail.
*
*    SELECT zi_intercorelationship~* FROM zi_intercorelationship
*      INNER JOIN zi_intercoproposalitem AS proposal_item
*        ON proposal_item~providercompanycode = zi_intercorelationship~providercompanycode AND
*           proposal_item~recipientcompanycode = zi_intercorelationship~recipientcompanycode
*      INTO TABLE @DATA(relationships).
*
*    data-relationships = relationships.
*
*    SELECT DISTINCT zi_intercopandlhierflattened~* FROM zi_intercopandlhierflattened
*      INNER JOIN @proposal_item_details AS item_details ON item_details~pandll5id = zi_intercopandlhierflattened~id
*    WHERE item_details~id = @proposal_id
*    INTO TABLE @DATA(pandls).
*
*    data-pandls = pandls.
*    RETURN data.

  ENDMETHOD.


  METHOD get_for_journalentry.

*Ini EXT_OSCUGALD 12.02.2026 - Excepción Genova
    DATA: lt_items_standard TYPE TABLE OF zi_intercoproposalitemcalcdet,
          lt_items_mla      TYPE TABLE OF zi_proposalitemcalcdet_mla.
    DATA: proposal_items_details TYPE tt_items_details.
    " 1. Verificamos si existe al menos un registro de Génova en el lote actual
    SELECT id
          FROM zi_proposalitem_mla
          FOR ALL ENTRIES IN @it_proposal_items
          WHERE id      = @it_proposal_items-id
            AND item_id = @it_proposal_items-item_id
            AND profitcenter = '0000000299'
          INTO TABLE @DATA(lt_check_mla)
          UP TO 1 ROWS.
    IF lt_check_mla IS NOT INITIAL.
      " --- RAMA MLA (GÉNOVA) ---
      " Consultamos la vista corregida: Producto real y datos de P&L vía túnel CeBe 200
      SELECT FROM zi_proposalitemcalcdet_mla AS proposal_items_calc_detail
        INNER JOIN @it_proposal_items AS _proposal_items ON _proposal_items~id      = proposal_items_calc_detail~id
                                                        AND _proposal_items~item_id   = proposal_items_calc_detail~item_id
                                                        AND _proposal_items~b_amountinglobalcurrency NE 0
      FIELDS DISTINCT
        proposal_items_calc_detail~id,
        proposal_items_calc_detail~product,
        proposal_items_calc_detail~item_id,
        _proposal_items~itembasis_id,
        _proposal_items~itemcalc_id,
        tarifftype,
        tariffdescription,
        tariffrate,
        glaccount,
        costcenter,
        costcenterd4,
        department,
        \_proposalitem-profitcenter,
        \_proposalitem-providercompanycode,
        \_proposalitem-recipientcompanycode,
        \_proposalitem-recipientcountry,
        \_proposalitem-profitcentereq,
        \_proposalitem\_proposal\_providercompanycode-currency AS companycodecurrency,
        \_proposalitem-globalcurrency,
        \_pandlflat-idl3,
        \_pandlflat-idl2,
        CASE WHEN \_proposalitem-recipientcountry = \_proposalitem-providercountry AND \_proposalitem-interdivisional IS INITIAL
          THEN proposal_items_calc_detail~amountincompanycodecurrency
          ELSE proposal_items_calc_detail~amountinglobalcurrency
        END AS amountintransactioncurrency,
        CASE WHEN \_proposalitem-recipientcountry = \_proposalitem-providercountry AND \_proposalitem-interdivisional IS INITIAL
          THEN proposal_items_calc_detail~companycodecurrency
          ELSE proposal_items_calc_detail~globalcurrency
        END AS transactioncurrency,
        proposal_items_calc_detail~amountinglobalcurrency,
        proposal_items_calc_detail~amountincompanycodecurrency,
        \_proposalitem\_relationship-recipientcustomer,
        \_proposalitem\_relationship-recipientvendor,
        _proposal_items~exchangerate,
        \_proposalitem-interdivisional
      WHERE proposal_items_calc_detail~id = @proposal_id AND tariffrate > 0
      INTO TABLE @DATA(proposal_items_details_mla).

      " Mapeo automático por nombre de campo
      proposal_items_details = CORRESPONDING #( proposal_items_details_mla ).
    ELSE.
*Fin EXT_OSCUGALD 12.02.2026 - Excepción Genova
      SELECT FROM zi_intercoproposalitemcalcdet AS proposal_items_calc_detail
        INNER JOIN @it_proposal_items AS _proposal_items ON _proposal_items~id = proposal_items_calc_detail~id
                                                        AND _proposal_items~item_id = proposal_items_calc_detail~item_id
      FIELDS DISTINCT
      proposal_items_calc_detail~id,
      proposal_items_calc_detail~product,
      proposal_items_calc_detail~item_id,
      _proposal_items~itembasis_id,
      _proposal_items~itemcalc_id,
      tarifftype,
      tariffdescription,
      tariffrate,
      glaccount,
      costcenter,
      costcenterd4,
      department,
      \_proposalitem-profitcenter,
      \_proposalitem-providercompanycode,
      \_proposalitem-recipientcompanycode,
      \_proposalitem-recipientcountry,
      \_proposalitem-profitcentereq,
      \_proposalitem\_proposal\_providercompanycode-currency AS companycodecurrency,
      \_proposalitem-globalcurrency,
        \_pandlflat-idl3,
        \_pandlflat-idl2,
        CASE WHEN \_proposalitem-recipientcountry = \_proposalitem-providercountry AND \_proposalitem-interdivisional IS INITIAL
          THEN proposal_items_calc_detail~amountincompanycodecurrency
          ELSE proposal_items_calc_detail~amountinglobalcurrency
        END AS amountintransactioncurrency,
        CASE WHEN \_proposalitem-recipientcountry = \_proposalitem-providercountry AND \_proposalitem-interdivisional IS INITIAL
          THEN proposal_items_calc_detail~companycodecurrency
          ELSE proposal_items_calc_detail~globalcurrency
        END AS transactioncurrency,
        proposal_items_calc_detail~amountinglobalcurrency,
        proposal_items_calc_detail~amountincompanycodecurrency,
        \_proposalitem\_relationship-recipientcustomer,
        \_proposalitem\_relationship-recipientvendor,
        _proposal_items~exchangerate,
        \_proposalitem-interdivisional
                WHERE proposal_items_calc_detail~id = @proposal_id AND tariffrate > 0
                INTO TABLE @proposal_items_details.

    ENDIF.
    RETURN proposal_items_details.
  ENDMETHOD.
ENDCLASS.
