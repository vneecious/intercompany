* PROCESS BEFORE OUTPUT.
*  MODULE LISTE_INITIALISIEREN.
*  LOOP AT EXTRACT WITH CONTROL
*   TCTRL_ZINT_A_MD_METRIC CURSOR NEXTLINE.
*    MODULE LISTE_SHOW_LISTE.
*  ENDLOOP.

* Ini Facturación Local CH/ARG EXT_OSCUGALD 25.10.2026 - G02A: ocultar
*columnas técnicas
PROCESS BEFORE OUTPUT.
  MODULE liste_initialisieren.
  MODULE g02a_ocultar_columnas.
  LOOP AT extract WITH CONTROL
   tctrl_zint_a_md_metric CURSOR nextline.
    MODULE liste_show_liste.
  ENDLOOP.
* Fin EXT_OSCUGALD 25.10.2026 - G02A
*
*
PROCESS AFTER INPUT.
  MODULE liste_exit_command AT EXIT-COMMAND.
  MODULE liste_before_loop.
  LOOP AT extract.
    MODULE liste_init_workarea.
* Ini Facturación Local CH/ARG EXT_OSCUGALD 25.10.2026 - G02A
* Incorporar vigencias al control de cambios.
*    CHAIN.
*     FIELD ZINT_A_MD_METRIC-ID .
*     FIELD ZINT_A_MD_METRIC-PROVIDER_COMPANY_CODE .
*     FIELD ZINT_A_MD_METRIC-PRODUCT .
*     FIELD ZINT_A_MD_METRIC-PAYMENT_TYPE .
*     FIELD ZINT_A_MD_METRIC-METRIC .
*     FIELD ZINT_A_MD_METRIC-IS_DELETED .
*     FIELD ZINT_A_MD_METRIC-CREATED_BY .
*     FIELD ZINT_A_MD_METRIC-LAST_CHANGED_BY .
*     MODULE SET_UPDATE_FLAG ON CHAIN-REQUEST.
*    ENDCHAIN.

    CHAIN.
      FIELD zint_a_md_metric-id .
      FIELD zint_a_md_metric-valid_from .
      FIELD zint_a_md_metric-valid_to .
      FIELD zint_a_md_metric-provider_company_code .
      FIELD zint_a_md_metric-product .
      FIELD zint_a_md_metric-payment_type .
      FIELD zint_a_md_metric-metric .
      FIELD zint_a_md_metric-is_deleted .
      FIELD zint_a_md_metric-created_by .
      FIELD zint_a_md_metric-last_changed_by .
      MODULE set_update_flag ON CHAIN-REQUEST.
    ENDCHAIN.
* Fin EXT_OSCUGALD 25.10.2026 - G02A
    FIELD vim_marked MODULE liste_mark_checkbox.
    CHAIN.
      FIELD zint_a_md_metric-id .
      MODULE liste_update_liste.
    ENDCHAIN.
  ENDLOOP.
  MODULE liste_after_loop.
