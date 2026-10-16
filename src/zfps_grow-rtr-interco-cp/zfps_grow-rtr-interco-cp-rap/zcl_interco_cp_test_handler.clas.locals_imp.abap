CLASS lcl_abap_behv_event_handler DEFINITION INHERITING FROM cl_abap_behavior_event_handler.

  PRIVATE SECTION.
    TYPES LTTY_PROPOSAL TYPE STANDARD TABLE OF ZI_IntercoProposal.
    METHODS  consume_test_event
       importing keys type LTTY_PROPOSAL." FOR ENTITY EVENT keys FOR ZI_IntercoProposal~testing,
    METHODS  Reverse_event
       IMPORTING KEYS TYPE LTTY_PROPOSAL."            FOR ENTITY EVENT keys FOR ZI_IntercoProposal~reversed.

ENDCLASS.



CLASS lcl_abap_behv_event_handler IMPLEMENTATION.

  METHOD consume_test_event.
*
*    DATA:
*      ls_interco_h TYPE zi_intercoproposal,
*      lt_interco_i TYPE TABLE OF ZI_IntercoProposalItem,
*      lt_interco_b TYPE TABLE OF ZI_IntercoProposalItemBasis,
*      lt_interco_c TYPE TABLE OF ZI_IntercoProposalItemCalc,
*      lt_interco_d TYPE TABLE OF zi_intercoproposalitemdoc.
*
*    DATA(ls_keys) = keys[ 1 ].
*    "Test to view how many documents with error NOT need to be re-process ( @zcl_proposal_bo_abs=>gc_status_commit, @zcl_proposal_bo_abs=>gc_status_anulated )
*    SELECT id, ItemId,  ItembasisId,  ItemcalcId,  Documenttype,  documentkey
*    FROM zi_intercoproposalitemdoc WHERE id EQ @ls_keys-id
*                                     AND status IN ( @zcl_proposal_bo_abs=>gc_status_commit, @zcl_proposal_bo_abs=>gc_status_anulated ) INTO TABLE @lt_interco_d.
*
*    SELECT SINGLE * FROM ZI_IntercoProposal WHERE id EQ @ls_keys-id INTO @ls_interco_h.
*
*    SELECT _c~* FROM zi_intercoproposalitemcalc AS _c
*    LEFT JOIN zi_intercoproposalitemdoc AS _d  ON _d~id             EQ _c~id
*                                              AND _d~ItemId         EQ _c~Item_Id
*                                              AND _d~ItembasisId    EQ _c~Itembasis_Id
*                                              AND _d~ItemcalcId     EQ _c~Itemcalc_Id
*                                              AND _d~status         IN ( @zcl_proposal_bo_abs=>gc_status_commit, @zcl_proposal_bo_abs=>gc_status_anulated )
*    WHERE _c~id EQ @ls_keys-id AND _c~commitstatus EQ @space INTO TABLE @lt_interco_c.
*
*    SELECT _b~* FROM ZI_IntercoProposalItemBasis  AS _b
*    INNER JOIN zi_intercoproposalitemcalc AS _c ON _b~id            EQ _c~id
*                                               AND _b~item_id       EQ _c~item_id
*                                               AND _b~itembasis_id  EQ _c~itembasis_id
*    LEFT JOIN zi_intercoproposalitemdoc AS _d  ON _d~id             EQ _c~id
*                                              AND _d~ItemId         EQ _c~Item_Id
*                                              AND _d~ItembasisId    EQ _c~Itembasis_Id
*                                              AND _d~ItemcalcId     EQ _c~Itemcalc_Id
*                                              AND _d~status         IN ( @zcl_proposal_bo_abs=>gc_status_commit, @zcl_proposal_bo_abs=>gc_status_anulated )
*     WHERE _c~id EQ @ls_keys-id
*     INTO TABLE @lt_interco_b.
*
*    SELECT _i~* FROM ZI_IntercoProposalItem AS _i
*    INNER JOIN ZI_IntercoProposalItemBasis  AS _b ON _b~id EQ _i~id
*                                               AND _b~item_id EQ _i~item_id
*    INNER JOIN zi_intercoproposalitemcalc AS _c ON _b~id EQ _c~id
*                                               AND _b~item_id EQ _c~item_id
*                                               AND _b~itembasis_id EQ _c~itembasis_id
*    LEFT JOIN zi_intercoproposalitemdoc AS _d  ON _d~id             EQ _c~id
*                                              AND _d~ItemId         EQ _c~Item_Id
*                                              AND _d~ItembasisId    EQ _c~Itembasis_Id
*                                              AND _d~ItemcalcId     EQ _c~Itemcalc_Id
*                                              AND _d~status         IN ( @zcl_proposal_bo_abs=>gc_status_commit, @zcl_proposal_bo_abs=>gc_status_anulated )
*     WHERE _c~id EQ @ls_keys-id
*     INTO TABLE @lt_interco_i.
*
*    IF  lines( lt_interco_c ) GT 0.
*      DATA(lo_proposal) = NEW zcl_boproposal_tools( is_header  = ls_interco_h
*                                                    it_items   = lt_interco_i[]
*                                                    it_bases   = lt_interco_b[]
*                                                    it_calc    = lt_interco_c[]
*                                                    it_doc     = lt_interco_d[]
*                                                    iv_process = zcl_boproposal_tools=>gc_create_doc ).
*
*      DATA(l_ref) = NEW cl_abap_parallel( ).
*      l_ref->run_inst(
*        EXPORTING
*          p_in_tab = VALUE #( ( lo_proposal ) )
**         p_debug  =
**        IMPORTING
**         p_out_tab = DATA(L_out_tab)
*      ).
**      LOOP AT l_out_tab ASSIGNING FIELD-SYMBOL(<l_out>) WHERE inst IS NOT INITIAL.
**        l_inst ?= <l_out>-inst.
**        "use result in L_INST->RESULT.
**      ENDLOOP.
*    ENDIF.
  ENDMETHOD.

  METHOD reverse_event.
*    DATA:
*      ls_interco_h TYPE zi_intercoproposal,
*      lt_interco_d TYPE TABLE OF ZI_IntercoProposalItemDoc.
*
*
*    DATA(ls_keys) = keys[ 1 ].
*
*    "Test to view how many documents need to be anulated or re-process anulation ( @zcl_proposal_bo_abs=>gc_status_commit, @zcl_proposal_bo_abs=>gc_status_error_anulated )
*    SELECT * FROM ZI_IntercoProposalItemDoc
*    WHERE id EQ @ls_keys-id
*    AND Status IN ( @zcl_proposal_bo_abs=>gc_status_commit, @zcl_proposal_bo_abs=>gc_status_error_anulated )
*    INTO TABLE @lt_interco_d.
*    CHECK sy-subrc EQ 0.
*
*    SELECT SINGLE * FROM ZI_IntercoProposal WHERE id EQ @ls_keys-id INTO @ls_interco_h.
*    DATA(lo_proposal) = NEW zcl_boproposal_tools( is_header  = ls_interco_h
*                                                  it_doc     = lt_interco_d[]
*                                                  iv_process = zcl_boproposal_tools=>gc_reverse_doc ).
*
*    DATA(l_ref) = NEW cl_abap_parallel( ).
*    l_ref->run_inst(
*      EXPORTING
*        p_in_tab = VALUE #( ( lo_proposal ) )
**       p_debug  =
**        IMPORTING
**       p_out_tab = DATA(L_out_tab)
*    ).
**      LOOP AT l_out_tab ASSIGNING FIELD-SYMBOL(<l_out>) WHERE inst IS NOT INITIAL.
**        l_inst ?= <l_out>-inst.
**        "use result in L_INST->RESULT.
**      ENDLOOP.
  ENDMETHOD.
ENDCLASS.
