CLASS zcl_interco_papm DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION..
    TYPES ty_key TYPE zi_intercoproposal-id.
    TYPES ty_keys TYPE TABLE OF ty_key.
    DATA gr_keys TYPE RANGE OF ty_key.

    INTERFACES if_abap_parallel.
    METHODS:
      constructor
        IMPORTING
          it_keys TYPE ty_keys.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_interco_papm IMPLEMENTATION.

  METHOD constructor.
    CHECK it_keys IS NOT INITIAL.
    gr_keys = VALUE #( FOR ls_key IN it_keys ( sign = 'I' option = 'EQ' low = ls_key ) ).

  ENDMETHOD.
  METHOD if_abap_parallel~do.
    CHECK gr_keys IS NOT INITIAL.

    DATA lt_reversed_proposals_range TYPE RANGE OF zi_intercoproposal-id.
    DATA lt_commited_proposals_range TYPE RANGE OF zi_intercoproposal-id.

    "EXT_OSCUGALD 22.10.2026 - PAPM: excluir productos fusion BR (ICSRV52-55) se agrega proposal~product
    SELECT proposal~id, proposal~status, proposal~product
    FROM zi_intercoproposal AS proposal
    WHERE id IN @gr_keys
      INTO TABLE @DATA(lt_proposals).


    lt_reversed_proposals_range = VALUE #( FOR ls_rev IN lt_proposals
                                              WHERE ( status = zcl_proposal_bo_abs=>c_proposal_status-anulated )
                                           ( sign = 'I' option = 'EQ' low = ls_rev-id ) ).

*Ini EXT_OSCUGALD 22.10.2026 - PAPM: excluir productos BR (ICSRV52-55)
    " Negocio: estos productos no deben cargarse en PAPM.
    " Lista maestra en TVARVC ZINTERCO_PAPM_EXCL_PRODUCT (un valor por fila en LOW).
    SELECT low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_PAPM_EXCL_PRODUCT'
      INTO TABLE @DATA(lt_excl_products).

    DATA lr_excl_product TYPE RANGE OF zi_intercoproposal-product.
    lr_excl_product = VALUE #( FOR ls_ex IN lt_excl_products
                               ( sign = 'I' option = 'EQ' low = ls_ex-low ) ).

    lt_commited_proposals_range = VALUE #( FOR ls_com IN lt_proposals
                                              WHERE ( status = zcl_proposal_bo_abs=>c_proposal_status-invoiced
                                                  AND product NOT IN lr_excl_product )
                                           ( sign = 'I' option = 'EQ' low = ls_com-id ) ).
*Fin EXT_OSCUGALD 22.10.2026 - PAPM: excluir productos BR (ICSRV52-55)

*    lt_commited_proposals_range = VALUE #( FOR ls_com IN lt_proposals
*                                              WHERE ( status = zcl_proposal_bo_abs=>c_proposal_status-invoiced )
*                                           ( sign = 'I' option = 'EQ' low = ls_com-id ) ).


    IF lt_reversed_proposals_range IS NOT INITIAL.
      DELETE FROM zfit_interc_papm WHERE id IN @lt_reversed_proposals_range.
      IF sy-subrc = 0.
        COMMIT WORK.
      ENDIF.
    ENDIF.

    IF lt_commited_proposals_range IS NOT INITIAL.
      DATA lt_new_proposals TYPE TABLE OF zfit_interc_papm.
      SELECT
         cds~id,
         item_id,
         itembasis_id,
         itemcalc_id,
         hkont,
         kostl,
         bukrs_prestadora,
         gjahr,
         monat,
         bukrs_prestataria,
         matnr,
         maktx,
         concepto,
         prctr,
         prctr_name,
         subbu,
         department AS departamento,
         hier_area,
         allocation,
         gloracctglobcurr,
         total,
         pl,
         totalconc,
         basisglobalcurr,
         base,
         mkup,
         gupb,
         gupk,
*         glaccountparentnode,
*         costcenterparentnode,
*         profitcenterparentnode,
         created_by,
         created_at
     FROM zi_intercopapm_ddic AS cds
     WHERE id IN @lt_commited_proposals_range
        INTO CORRESPONDING FIELDS OF TABLE @lt_new_proposals.

*Ini EXT_OSCUGALD 03.09.2026 - Genova MLA: evitar duplicado CeBe 200/299 en PAPM
      " Ajuste: identifica sociedades receptoras (bukrs_prestataria) que tienen
      " una linea con Centro de Beneficio 200 (origen) y, si existe, descarta
      " su linea 299 equivalente (destino regional) para no duplicar el importe
      " en el reporte PAPM. Confirmado con negocio: se conserva 200, se elimina 299.
      DATA lt_genova_active TYPE RANGE OF bukrs.

      lt_genova_active = VALUE #(
          FOR item IN lt_new_proposals WHERE ( prctr = '0000000200' )
          ( sign = 'I' option = 'EQ' low = item-bukrs_prestataria ) ).

      IF lt_genova_active IS NOT INITIAL.
        DELETE lt_new_proposals WHERE ( prctr = '0000000299'
                                     AND bukrs_prestataria IN lt_genova_active ).
      ENDIF.
*Fin EXT_OSCUGALD 03.09.2026 - Genova MLA: evitar duplicado CeBe 200/299 en PAPM

      MODIFY zfit_interc_papm FROM TABLE @lt_new_proposals.
      IF sy-subrc = 0.
        COMMIT WORK.
      ENDIF.
    ENDIF.


*    DATA lt_interc_papm TYPE STANDARD TABLE OF zfit_interc_papm.
*    SELECT
*        id,
*        item_id,
*        itembasis_id,
*        itemcalc_id,
*        hkont,
*        kostl,
*        bukrs_prestadora,
*        gjahr,
*        monat,
*        bukrs_prestataria,
*        matnr,
*        productname AS maktx,
*        concepto,
*        prctr,
*        profitcentername AS prctr_name,
*        subbu,
*        department AS departamento,
*        khinr AS hier_area,
*        alloc_cc AS allocation,
*        gloracctglobalcurrency AS gloracctglobcurr,
*        total,
*        pl,
*        totalconc,
*        basisglobalcurrency AS basisglobalcurr,
*        base,
*        mkup,
*        gupb,
*        gupk,
*        glaccountparentnode,
*        costcenterparentnode,
*        profitcenterparentnode,
*        createdby AS created_by,
*        createdat AS created_at
*    FROM zi_intercopapm_ddic AS cds
*    WHERE cds~id IN @gr_keys
*       INTO TABLE @DATA(lt_delta).
*
*    IF lt_delta IS NOT INITIAL.
*      MOVE-CORRESPONDING lt_delta TO lt_interc_papm.
*      MODIFY zfit_interc_papm FROM TABLE @lt_interc_papm.
*      IF sy-subrc = 0.
*        COMMIT WORK.
*      ELSE.
*        ROLLBACK WORK.
*      ENDIF.
*    ELSE.
*    ENDIF.

  ENDMETHOD.


ENDCLASS.
